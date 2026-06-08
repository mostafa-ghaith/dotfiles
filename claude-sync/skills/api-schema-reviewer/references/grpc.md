# gRPC / Protobuf Review Criteria

Use this reference when reviewing `.proto` files (proto3 primarily) or gRPC service definitions. Criteria are drawn from the protobuf style guide, Google AIPs, and the Buf style guide.

## Table of Contents

1. [File layout & organization](#1-file-layout--organization)
2. [Naming](#2-naming)
3. [Field numbers](#3-field-numbers)
4. [Types & field rules](#4-types--field-rules)
5. [Messages](#5-messages)
6. [Enums](#6-enums)
7. [Services & RPCs](#7-services--rpcs)
8. [Streaming](#8-streaming)
9. [Errors](#9-errors)
10. [Wire & source compatibility](#10-wire--source-compatibility)
11. [Documentation](#11-documentation)

---

## 1. File layout & organization

- `syntax = "proto3";` at the top (proto2 is legacy; flag proto2 for new services).
- `package` declared and matches directory structure: `package myorg.billing.v1;` in `myorg/billing/v1/*.proto`.
- **Versioned package names** (`v1`, `v1alpha1`, `v2`). No version = pre-1.0 and unstable; flag missing version in anything production-facing.
- One top-level service or tightly-related group per file. Don't put 10 unrelated services in one proto.
- File names are `lower_snake_case.proto`: `user_service.proto`, not `UserService.proto`.
- Imports are explicit and minimal. No transitive reliance.
- `go_package`, `java_package`, `csharp_namespace` etc. set appropriately for codegen.

## 2. Naming

- **Messages & services**: `PascalCase` — `GetUserRequest`, `UserService`.
- **Fields**: `lower_snake_case` — `user_id`, `created_at`. The generated language bindings convert appropriately (`userId` in Java, `user_id` in Python).
- **Enum types**: `PascalCase` — `OrderStatus`.
- **Enum values**: `SCREAMING_SNAKE_CASE`, **prefixed with the enum name** to avoid collision (proto enums are C-style — values are in the enclosing scope):
  ```proto
  enum OrderStatus {
    ORDER_STATUS_UNSPECIFIED = 0;
    ORDER_STATUS_PENDING = 1;
    ORDER_STATUS_SHIPPED = 2;
  }
  ```
- **RPC methods**: `PascalCase` verb-first — `CreateUser`, `ListOrders`, `StreamLogs`.
- **Request/response messages**: `<Rpc>Request` / `<Rpc>Response`: `CreateUserRequest`, `CreateUserResponse`. Don't share request messages across RPCs — you lose the ability to evolve them independently.

## 3. Field numbers

Field numbers are the wire contract. Getting them wrong is catastrophic.

- **Never reuse a field number**. If you remove a field, mark it `reserved`:
  ```proto
  reserved 3, 5 to 7;
  reserved "old_field", "legacy_name";
  ```
- **1–15** are cheaper on the wire (1 byte). Use for frequently-set fields.
- **16–2047** are 2 bytes.
- **19000–19999** are reserved by protobuf; don't use.
- Never reassign an existing field to a new type — even if wire-compatible, it's a source-compatibility break.

Blocker-level issues:
- Reusing a field number on a message that's already been deployed.
- Removing a field without a `reserved` entry.
- Changing a field's type to a non-wire-compatible type (e.g., `int32` → `string`).

## 4. Types & field rules

**Scalar choice:**

- `int32`/`int64` — signed ints. Use `int64` for IDs, counts that may grow, timestamps in ms.
- `sint32`/`sint64` — use when values are often negative (better varint encoding).
- `uint32`/`uint64` — unsigned. Note: languages like Java don't have unsigned types; plan for it.
- `fixed32`/`fixed64` — fixed-size; efficient when values are usually large.
- `float`/`double` — floats. Don't use for money.
- `bool` — fine, but prefer enums if there might ever be a third state.
- `string` — UTF-8 text. Validation is the service's job.
- `bytes` — arbitrary bytes. Don't use for text.

**Field rules in proto3:**

- Singular (default) — can't distinguish "not set" from "default value" (0, "", false). If that distinction matters, wrap in `google.protobuf.*Value` (`StringValue`, `Int32Value`, etc.) or use `optional` (proto3 supports `optional` since 3.15, which adds presence tracking).
- `repeated` — list. Empty list and unset are indistinguishable.
- `map<K, V>` — convenience for repeated key/value pairs. Key must be scalar (not float/bytes/message). Order is not preserved.
- `oneof` — at most one field set. Good for "type A or type B" modeling.
- No `required` in proto3 — removed intentionally. All fields are optional on the wire.

**Standard types to prefer:**

- `google.protobuf.Timestamp` for absolute time (not `int64 unix_seconds`).
- `google.protobuf.Duration` for time spans.
- `google.protobuf.FieldMask` for partial updates.
- `google.protobuf.Empty` for RPCs that take or return nothing (but prefer a dedicated empty message you can evolve).
- `google.protobuf.Struct` / `Any` as last resorts — they defeat the type system.

## 5. Messages

- One concept per message. Don't bundle unrelated fields.
- Don't mirror your database row. Model the domain.
- Nested messages are fine for tightly-scoped types. Promote to top-level when reused across messages.
- Avoid deeply nested messages (>3 levels) — painful for codegen in some languages.
- Don't use field number 1 for things that might change — consider reserving it if unsure.

## 6. Enums

- First value **must** be `<ENUM_NAME>_UNSPECIFIED = 0;`. proto3 defaults unset fields to 0; having a meaningful 0 value means "unset" is indistinguishable from that value.
- Enums are additively extensible. Clients must tolerate unknown values (proto3 preserves them as their numeric value; codegen typically surfaces as a sentinel).
- Never renumber existing values.
- Never reuse a numeric value for a different meaning. Reserve retired ones:
  ```proto
  reserved 3, 4;
  reserved "OLD_STATUS_DELETED";
  ```
- If an enum has a chance of being open-ended (e.g., "country code"), consider `string` instead.

## 7. Services & RPCs

Naming conventions for standard methods (Google AIP-130):

- `Get<Resource>` — read one
- `List<Resource>` — read many (paginated)
- `Create<Resource>` — create one
- `Update<Resource>` — update one (takes a `FieldMask` for partial update)
- `Delete<Resource>` — delete one
- Custom methods: `<Verb><Resource>` — `CancelOrder`, `ArchiveProject`

Each RPC takes **one request message and returns one response message**, even if the request has a single field:

```proto
rpc GetUser(GetUserRequest) returns (User);
// vs (wrong — can't evolve)
rpc GetUser(string id) returns (User);
```

Wrong patterns:

- RPC name that doesn't match the pattern: `UserFetch`, `GetUserData`.
- Shared request messages across multiple RPCs — you can't evolve them independently.
- Returning a scalar instead of a message — can't add fields later.
- Using `google.protobuf.Empty` as response — no room to add status/metadata later.
- Response messages used to wrap single fields: return the resource directly when the RPC is "get one".

## 8. Streaming

Four RPC types:

1. **Unary** — one request, one response. Default.
2. **Server streaming** — one request, stream of responses. Good for server-push feeds.
3. **Client streaming** — stream of requests, one response. Rare; use for batched uploads.
4. **Bidirectional streaming** — full duplex. Use for chat-like or long-running session RPCs.

Review checks:

- Streaming should be justified. Unary is simpler; most RPCs are unary.
- Document the semantics: what does "done" mean? What about reconnection? What's the ordering guarantee?
- Streaming responses should specify whether clients can assume completeness (e.g., the server will always close cleanly).

## 9. Errors

gRPC uses status codes + optional `google.rpc.Status` with `details`:

- Canonical status codes: `OK`, `CANCELLED`, `INVALID_ARGUMENT`, `DEADLINE_EXCEEDED`, `NOT_FOUND`, `ALREADY_EXISTS`, `PERMISSION_DENIED`, `UNAUTHENTICATED`, `RESOURCE_EXHAUSTED`, `FAILED_PRECONDITION`, `ABORTED`, `OUT_OF_RANGE`, `UNIMPLEMENTED`, `INTERNAL`, `UNAVAILABLE`, `DATA_LOSS`.
- Use the right code. `INTERNAL` for unexpected server errors; `FAILED_PRECONDITION` for state conflicts; `INVALID_ARGUMENT` for validation; `UNAVAILABLE` for retryable transient failures.
- Include `google.rpc.ErrorInfo` in `Status.details` for structured error codes the client can switch on.
- Don't invent your own error envelopes in response messages — use the gRPC status layer. Mixing the two creates inconsistency.

## 10. Wire & source compatibility

**Wire-compatible changes (safe):**

- Adding new fields (with new field numbers)
- Adding new RPC methods
- Adding new enum values (with caveat about clients handling unknowns)
- Adding new messages

**Breaking changes (require a new major version / new package):**

- Renaming fields (source break; wire OK for proto3 since names aren't on the wire, but JSON serialization and codegen break)
- Changing field types between non-wire-compatible types
- Removing fields without reserving
- Changing field numbers
- Renaming or removing RPCs
- Changing RPC request or response types
- Changing streaming kind (unary ↔ streaming)

For versioned packages, the convention is: bump from `v1` to `v2` for breaking changes. Old versions stay supported for a deprecation window.

## 11. Documentation

- Every message, field, enum value, service, and RPC has a `//` comment.
- Comments describe semantics, not syntax. "The user's email address" is not useful; "Unique email, used as a secondary login identifier. RFC 5321 compliant, max 254 chars." is.
- Note required-in-practice fields even though proto3 has no `required`: `// Required. The user's email.`
- Document RPC-level things:
  - Idempotency
  - Side effects
  - Authentication / authorization requirements
  - Rate limits
  - Ordering guarantees (especially for streaming)
