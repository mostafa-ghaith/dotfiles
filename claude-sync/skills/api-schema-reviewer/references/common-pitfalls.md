# Common API Design Pitfalls (cross-cutting)

These apply to every style — REST, GraphQL, gRPC. Read this in addition to the style-specific reference.

## Table of Contents

1. [Consistency](#1-consistency)
2. [Naming traps](#2-naming-traps)
3. [Data modeling](#3-data-modeling)
4. [Error modeling](#4-error-modeling)
5. [Time, money, IDs](#5-time-money-ids)
6. [Evolvability & backwards compatibility](#6-evolvability--backwards-compatibility)
7. [Security](#7-security)
8. [Documentation](#8-documentation)
9. [Things reviewers over-flag](#9-things-reviewers-over-flag)

---

## 1. Consistency

Inconsistency is the #1 long-term pain point in APIs. Catalog every inconsistency and surface them together rather than scattered across findings:

- Casing (snake vs camel vs kebab)
- Pagination parameter names (`limit` vs `pageSize`, `offset` vs `page` vs `pageToken`)
- Date field suffix (`_at` vs `_date` vs `_time` vs none)
- ID field naming (`id` vs `<entity>_id` vs `<entity>Id`)
- Error envelope shape
- Response shape (bare vs enveloped)
- "Yes/no" field naming (`active` vs `is_active` vs `enabled`)
- Collection field naming (`tags` vs `tag_list` vs `tags_array`)

If the schema is 80% one style and 20% another, the 20% is almost always a mistake from a different author.

## 2. Naming traps

- **Abbreviations**. `usr`, `prj`, `desc`, `cnt`, `amt`. Only universal abbreviations are OK (`id`, `url`, `ip`, `uuid`).
- **Technical leakage**. `mongoId`, `tableRow`, `fkUserId`, `rowVersion`, `dirty`, `cached`. These reveal implementation.
- **Negative booleans**. `isNotDeleted`, `disabled`. Always use positive: `isDeleted`, `enabled`. Double-negatives bite.
- **Ambiguous plurals**. `children` is fine; `childs` is not. `data` is too generic.
- **Reserved-ish words**. `type`, `class`, `new`, `delete` conflict with reserved words in common client languages; codegen gets ugly.
- **Enum values that look like free text**. `"Premium Customer"` (with space) — pick `PREMIUM_CUSTOMER` or `premium_customer`.
- **Type-in-field-name**. `emailString`, `countInt`. Redundant — the type system already says it.

## 3. Data modeling

- **Stringly-typed data**. `status: "active"` as a free-form string is worse than an enum. If values are constrained, enum.
- **Stringly-typed structured data**. `address: "123 Main St, Seattle, WA 98101"` — clients can't parse it. Use an object.
- **Catch-all maps**. `metadata: map<string, string>` is OK for truly open-ended extension; a smell when the fields are known in advance.
- **Booleans where enums will be needed**. `isPublic: boolean` → next year, `visibility: PUBLIC | PRIVATE | UNLISTED`. When in doubt, enum.
- **Fields that collapse distinct concepts**. `createdBy: string` storing "user:123" or "system" or "admin:456" — should be structured.
- **Missing required-ness**. Every field must be clearly either required or optional (even in proto3, use comments or the `optional` keyword for presence).

## 4. Error modeling

- **One error shape across the whole API**. Define it once, use it everywhere. A user who learns to parse `errors[].code` at one endpoint shouldn't have to learn a different shape at the next.
- **Machine-readable codes over messages**. `USER_NOT_FOUND` is stable; `"User with ID 123 was not found"` is not.
- **Don't leak internals**. No stack traces, SQL errors, database names, internal hostnames in error responses.
- **Field-level validation errors**. Point at the specific field (`errors[].field` or JSON Pointer). "Invalid request" is useless.
- **Separate "expected" errors from "unexpected"**. Validation failures are expected; DB timeouts are not. Clients handle them differently.

## 5. Time, money, IDs

**Time:**

- Always include timezone information. ISO 8601 / RFC 3339 strings (`2025-01-15T10:30:00Z`).
- Don't invent "2025-01-15 10:30:00 PST" — not parseable universally.
- Durations: explicit units in the field name (`timeoutSeconds`) or ISO 8601 duration (`PT5M`).
- Epoch is OK if documented and the unit is stated (`createdAtMillis`, not just `createdAt: int`).

**Money:**

- Never use floats. `float` or `double` for money is a blocker, always.
- Preferred: `{ amount: "19.99", currency: "USD" }` or an integer minor-unit (`amount_cents: 1999, currency: "USD"`).
- Currency is always required alongside amount; never assume a default.

**IDs:**

- Opaque. Don't let clients parse them ("the prefix tells you the type").
- Stable. An ID should identify the same object forever.
- URL-safe. No `/`, `?`, `#`, spaces.
- Globally unique within the resource type; ideally globally unique across the system (UUIDs, ULIDs, or prefixed opaque tokens like Stripe's `cus_abc123`).
- Don't use auto-increment integers for public-facing IDs — leaks volume, enables enumeration.

## 6. Evolvability & backwards compatibility

**Breaking changes to flag (blocker on released APIs):**

- Removing a field / endpoint / method
- Renaming anything
- Changing a type (including nullability to stricter, or widening to a supertype)
- Adding a required field to a request
- Tightening validation (shorter max length, stricter pattern)
- Changing enum value meanings
- Reusing a proto field number
- Changing HTTP status codes or gRPC status codes for the same logical outcome
- Changing pagination semantics

**Safe additive changes:**

- New fields (optional)
- New endpoints / methods
- New enum values, **if** the API contract says clients must tolerate unknowns (document this)
- Loosening validation

**Deprecation path:**

- Mark the deprecated thing (`deprecated: true` in OpenAPI, `@deprecated` in GraphQL, `[deprecated = true]` in proto).
- Document the replacement in the description.
- Keep the deprecated thing working for a documented window.
- Communicate via changelog, release notes, and (for HTTP) `Sunset` / `Deprecation` headers.

## 7. Security

- **Authentication**: every write endpoint, most reads. Document which endpoints are public.
- **Authorization**: schema review flags fields that look sensitive (`ssn`, `creditCardNumber`, `internalNotes`). Ensure the design has an authz story.
- **Input validation**: every string has max length, every array has max items, every number has bounds. Without these, a single malicious request can DoS.
- **Rate limiting**: design-level concern. Document limits and the response when exceeded.
- **PII in URLs/logs**: no tokens, emails, SSNs in paths or query strings — they land in server logs, proxy logs, referrer headers.
- **Over-fetching**: endpoints returning full user objects including sensitive fields to low-privilege callers.
- **IDOR**: `GET /users/{id}/documents/{docId}` — does the service check `docId` actually belongs to `id`, or only that the caller can see `id`?
- **Mass assignment**: `PUT /users/{id}` accepting any field in the body including `role` or `isAdmin`. Explicitly whitelist writable fields.

## 8. Documentation

- Every type/field/operation has a description.
- Descriptions are written for the **client**, not the implementer.
- No TODOs, "fix later", "do not use" notes in public descriptions.
- Examples for anything where the format isn't obvious.
- Units documented (bytes vs KB, seconds vs ms, cents vs dollars).
- Constraints documented (max length, allowed characters, range).
- Nullability / required-ness documented.

## 9. Things reviewers over-flag

Don't flag these as problems:

- **Snake_case vs camelCase for a whole schema**. Both are legitimate. Only flag mixing.
- **Envelope vs bare responses**. Preference. Only flag inconsistency.
- **PATCH vs PUT for updates**. Different valid approaches.
- **Cursor vs offset pagination**. Both OK; cursor is better for large or changing datasets but offset is fine for bounded ones.
- **Proprietary vs RFC 7807 error format**. If internally consistent and documented, fine.
- **Verbosity of field names**. Short is fine if clear. `createdAt` over `creationTimestamp` is OK.
- **Whether to include `totalCount` in paginated responses**. Depends on use case.
- **Whether IDs are UUIDs, ULIDs, or prefixed opaque tokens**. All valid.

Flag these as `nit` or note as a convention choice, not a `blocker` or `major`.
