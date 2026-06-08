# GraphQL Review Criteria

Use this reference when reviewing GraphQL SDL (`.graphql` / `.gql`), schemas defined inline, or a GraphQL API design doc. Criteria are drawn from the GraphQL spec, Apollo/GitHub/Shopify style guides, and the "Production Ready GraphQL" community.

## Table of Contents

1. [Schema design principles](#1-schema-design-principles)
2. [Naming](#2-naming)
3. [Types, nullability, lists](#3-types-nullability-lists)
4. [Queries](#4-queries)
5. [Mutations](#5-mutations)
6. [Subscriptions](#6-subscriptions)
7. [Pagination (Relay connections)](#7-pagination-relay-connections)
8. [IDs, nodes, interfaces](#8-ids-nodes-interfaces)
9. [Error handling](#9-error-handling)
10. [Versioning & evolvability](#10-versioning--evolvability)
11. [Security & operational concerns](#11-security--operational-concerns)
12. [Documentation](#12-documentation)

---

## 1. Schema design principles

- **Design for the client.** A GraphQL schema is a product API, not an ORM export. Fields should reflect what clients actually want to render, not database columns. Flag 1:1 DB mirrors.
- **Schema first, resolvers second.** The schema is the contract; changing it breaks clients. Apply more discipline here than in REST.
- **Prefer object composition over field proliferation.** `user.address.city` is better than `user.userAddressCity`.
- **Hide implementation details.** Don't expose join tables, technical IDs, or infrastructure concepts (e.g., `ShardID`, `DatabaseRow`).

## 2. Naming

Canonical GraphQL convention (Apollo/Relay):

- **Types**: `PascalCase` — `User`, `OrderLineItem`
- **Fields & arguments**: `camelCase` — `firstName`, `createdAt`
- **Enum values**: `SCREAMING_SNAKE_CASE` — `ORDER_STATUS_SHIPPED`
- **Interfaces**: `PascalCase`, often descriptive — `Node`, `Timestamped`, not `INode` or `IUser` (C#-ism)
- **Mutations**: verb-first, `camelCase` — `createUser`, `cancelOrder`. Domain-grouped is clearer: `userCreate`, `orderCancel` (Shopify style) — either is fine if consistent.

Smells:

- Type names with suffixes like `DTO`, `Model`, `Entity`, `GQL` — leaked from code.
- Generic names: `Item`, `Thing`, `Data`. Name for the domain.
- Field names that reveal implementation: `rowId`, `mongoId`, `fkUserId`.
- Inconsistent casing in a single schema — flag as a blocker for pre-release, major for released schemas.

## 3. Types, nullability, lists

**Nullability is the single most impactful decision in a GraphQL schema.**

- Default to nullable. Non-null (`!`) is a contract: the server must always return a value, or the query fails and cascades null up to the nearest nullable parent.
- Use `!` on fields that are truly always-present and cheap to compute. Use `!` on IDs of existing objects.
- Avoid `!` on fields that depend on external services — one upstream failure nulls the whole parent.
- List nullability has four forms; pick intentionally:
  - `[User]` — list may be null, items may be null (permissive)
  - `[User]!` — list non-null, items may be null
  - `[User!]` — list may be null, items non-null
  - `[User!]!` — list non-null, items non-null (strictest; use when you mean "never empty null list")
- Prefer `[User!]!` for most collections. Empty list beats null list.
- Don't overuse scalars. Model structured data as object types. `address: String` with a formatted blob is a smell; `address: Address { street, city, ... }` is better.
- Use custom scalars for primitives with semantics: `DateTime`, `Email`, `URL`, `UUID`. Document the serialization format.

## 4. Queries

- One root `Query` type per schema. Fields on `Query` are the top-level entry points.
- Provide a way to fetch any fetchable object by ID: either the Relay `node(id: ID!): Node` pattern, or per-type fields like `user(id: ID!): User`. Prefer `node` for generic client caches.
- Field arguments should be documented and typed. Avoid catch-all `filter: JSON` — it defeats GraphQL's type system. Model filters as input objects.
- Avoid deeply-coupled query shapes like `search(query: SearchQueryInput!)` where `SearchQueryInput` has 20 optional fields — prefer split queries or explicit union input types.

## 5. Mutations

- Each mutation does **one thing**. Composite mutations (`updateUserAndSendEmail`) are usually wrong.
- Use **input objects** for mutation arguments — `mutation createUser(input: CreateUserInput!)`. Lets you add fields without renaming the mutation.
- Return a **payload object**, not the bare mutated type. Payload includes the entity plus a `userErrors` / `errors` field for predictable error handling:
  ```graphql
  type CreateUserPayload {
    user: User
    userErrors: [UserError!]!
  }
  ```
- Naming: `<entity><Verb>` (Shopify) or `<verb><Entity>` (Apollo/GitHub). Be consistent.
- Mutations must be explicit about idempotency. Document which are idempotent, which aren't.

## 6. Subscriptions

- Use sparingly. A subscription is a stateful connection — infrastructure cost is real.
- Each subscription field emits one event type, not a grab-bag. `orderStatusChanged(orderId: ID!): OrderStatusEvent!`, not `events: JSON`.
- Document the delivery semantics: at-least-once vs at-most-once, order guarantees, reconnection behavior.

## 7. Pagination (Relay connections)

The Relay Cursor Connection Spec is the de facto standard:

```graphql
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
}
type UserEdge {
  cursor: String!
  node: User!
}
type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}
```

Common issues:

- Returning bare `[User!]!` for collections that can grow unbounded — unbounded lists are a DoS risk. Every list field should have pagination or a documented hard cap.
- Using offset-based pagination as `first: Int, offset: Int` — works but inconsistent with the rest of the GraphQL ecosystem.
- Cursors that encode offsets instead of stable positions — breaks under concurrent inserts.
- Missing `totalCount` when clients need it — but avoid always including it; it's often expensive to compute.

## 8. IDs, nodes, interfaces

- `ID` is a scalar meaning "globally unique opaque identifier". Don't use `String` for IDs.
- Use the Relay `Node` interface for fetchable objects:
  ```graphql
  interface Node {
    id: ID!
  }
  ```
- Global IDs are typically base64(type:local_id). Helps client caches and `node(id:)` resolution.
- Use interfaces to share fields across types (`interface Timestamped { createdAt: DateTime!, updatedAt: DateTime! }`).
- Use unions for "one of several unrelated types" (`union SearchResult = User | Post | Comment`).
- Don't use interfaces purely for code reuse in resolvers — they're a client contract.

## 9. Error handling

GraphQL has two error channels. Use both deliberately:

1. **Top-level `errors` array** (from the spec) — for failures the client can't recover from: network, syntax, authorization, unexpected exceptions.
2. **Field errors in payload** — for expected domain errors (validation, "email already taken"). These are first-class data; the client renders them in the UI.

Pattern:

```graphql
type CreateUserPayload {
  user: User
  userErrors: [UserError!]!
}
type UserError {
  field: [String!]
  message: String!
  code: UserErrorCode!
}
```

Common issues:

- All errors in top-level `errors` — forces clients to parse error messages to distinguish "wrong password" from "server exploded".
- No stable `code` field — clients depend on message strings.
- Errors in the wrong channel — an auth failure is not a `userError`; a validation failure is not a top-level error.
- Exposing internal details in messages (SQL errors, stack traces).

## 10. Versioning & evolvability

GraphQL versioning is field-level, not whole-schema:

- Never remove or rename a field in a released schema. Add a new field, mark the old `@deprecated(reason: "...")`.
- Enum values are a common trap — adding values can break non-exhaustive client code, but is standard practice. Document it.
- Breaking changes (for change review):
  - Removing a type, field, or enum value
  - Changing a field's type (even to a supertype can break some clients)
  - Changing nullability from nullable to non-null on arguments (requires clients to provide)
  - Changing nullability from non-null to nullable on return types (clients may have assumed non-null)
  - Renaming anything
  - Removing an interface implementation
- Non-breaking (generally safe): adding types, adding fields, adding optional arguments, adding enum values (with caveat above), adding interface implementations.

## 11. Security & operational concerns

- **Query depth / complexity limits** must be documented. GraphQL's recursive nature means clients can write `user { friends { friends { friends { ... } } } }` and DoS you. Schemas should be reviewed for cycles that allow unbounded nesting.
- **Unbounded lists** are a DoS vector. Every list field needs pagination or a hard cap.
- **N+1 resolvers**: flag fields where naive resolution would fan out. DataLoader is standard.
- **Authorization at the resolver**: schema review should note which fields need authz. A `User.emailAddress` field accessible to any authenticated user is often wrong.
- **Introspection**: often disabled in production for public APIs; enabled for partner / internal.
- **Query cost analysis**: complex schemas should document a cost model.

## 12. Documentation

- Every type, field, argument, and enum value has a description (triple-quoted string `"""..."""` above the definition).
- Descriptions are written for clients, not implementers — no "TODO refactor this", no DB column references.
- Deprecations explain the replacement: `@deprecated(reason: "Use `emailAddress` instead")`, not just `@deprecated(reason: "Deprecated")`.
- Examples are included in descriptions where the format isn't obvious (e.g., date format for custom scalars).
