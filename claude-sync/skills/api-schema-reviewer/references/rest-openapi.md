# REST / OpenAPI Review Criteria

Use this reference when reviewing OpenAPI 2.0 (Swagger) / 3.x specs or REST API design docs. Criteria are drawn from Google AIPs, Microsoft REST API Guidelines, Zalando RESTful Guidelines, and RFC 7231/9110.

## Table of Contents

1. [Resource modeling](#1-resource-modeling)
2. [URI structure](#2-uri-structure)
3. [HTTP methods & semantics](#3-http-methods--semantics)
4. [Status codes](#4-status-codes)
5. [Request/response bodies](#5-requestresponse-bodies)
6. [Naming & casing](#6-naming--casing)
7. [Data types & validation](#7-data-types--validation)
8. [Error model](#8-error-model)
9. [Pagination, filtering, sorting](#9-pagination-filtering-sorting)
10. [Versioning & evolvability](#10-versioning--evolvability)
11. [Security](#11-security)
12. [OpenAPI-specific hygiene](#12-openapi-specific-hygiene)

---

## 1. Resource modeling

- Endpoints are organized around **nouns (resources)**, not verbs. `/users/{id}/activate` is an RPC smell; prefer `POST /users/{id}:activate` (Google AIP custom method) or a state field update.
- Plural collection nouns: `/users`, not `/user`. Singletons (e.g., `/me`, `/settings`) may be singular.
- Hierarchy reflects ownership: `/projects/{projectId}/tasks/{taskId}`. Don't nest more than 2–3 levels — clients can't bookmark deep trees cleanly.
- The same resource should appear at one canonical path. If it must appear in multiple places (e.g., `/users/{id}/tasks` and `/tasks?userId=`), document which is canonical.

## 2. URI structure

- Path segments are **lowercase**, **kebab-case** when multi-word: `/task-lists`, not `/taskLists` or `/task_lists`.
- No trailing slashes (pick one, be consistent).
- Query parameters use **camelCase** or **snake_case** — be consistent across the whole spec.
- No verbs in paths (`/getUser` is wrong; it's `GET /users/{id}`).
- Stable, opaque IDs in paths. Avoid paths that expose internal structure (e.g., `/users/db-123/profile` leaks the "db-" prefix).

## 3. HTTP methods & semantics

| Method   | Use for                            | Idempotent | Safe |
| -------- | ---------------------------------- | ---------- | ---- |
| `GET`    | Read (no side effects)             | Yes        | Yes  |
| `POST`   | Create, non-idempotent actions     | No         | No   |
| `PUT`    | Full replace / upsert at known URI | Yes        | No   |
| `PATCH`  | Partial update                     | No*        | No   |
| `DELETE` | Remove                             | Yes        | No   |

Common issues to flag:

- `GET` with a request body, or that has side effects — violates RFC and breaks caches/retries.
- `POST` used for retrievals just to avoid query-string length limits — prefer a well-defined search resource (`POST /searches`) or cursor.
- `PUT` used for partial updates (should be `PATCH`).
- `PATCH` without a defined patch format (JSON Merge Patch RFC 7396, JSON Patch RFC 6902, or an explicit partial-update schema).
- `DELETE` returning the deleted entity in a body where clients must handle 204 vs 200 — pick one.
- Missing idempotency support on create (`POST`). For resources where duplicates are costly, provide an `Idempotency-Key` header (Stripe pattern) or use `PUT` with client-generated IDs.

## 4. Status codes

Standard mapping:

- `200 OK` — success with body
- `201 Created` — resource created; should include `Location` header
- `202 Accepted` — async operation queued; should point to an operation/status resource
- `204 No Content` — success, no body (good for `DELETE`, empty `PATCH`)
- `400 Bad Request` — malformed request (syntax, validation)
- `401 Unauthorized` — not authenticated
- `403 Forbidden` — authenticated but not authorized
- `404 Not Found` — resource doesn't exist (or is hidden from this caller)
- `409 Conflict` — state conflict (e.g., duplicate, stale ETag)
- `410 Gone` — permanently removed (useful for deprecated endpoints)
- `412 Precondition Failed` — `If-Match`/`If-Unmodified-Since` failed
- `415 Unsupported Media Type` — body content type not accepted
- `422 Unprocessable Entity` — syntactically valid but semantically rejected (common for validation)
- `429 Too Many Requests` — rate-limited; should include `Retry-After`
- `5xx` — server errors; never leak stack traces

Common issues:

- Using `200` with an error envelope instead of the right 4xx/5xx — forces clients to parse the body to know if it failed.
- Using `404` to mean "not authorized" — OK as a privacy measure only if documented.
- Using `400` for every client error — `409`/`422` are often more specific.
- Missing `201` `Location` header on creates.
- Missing `Retry-After` on `429` and `503`.

## 5. Request/response bodies

- **One content type per operation** unless there's a clear reason (upload endpoints may also accept multipart). Prefer `application/json`.
- Response shape should be predictable across similar operations. If the collection endpoint returns `{ items: [...], nextPageToken: ... }`, every collection endpoint should use the same envelope.
- Envelope consistency is more important than envelope-vs-bare preference. Pick one and stick with it.
- Creates return `201` + the created resource (with server-assigned fields: `id`, `createdAt`).
- Updates return `200` + the updated resource (or `204` if intentionally not returning).
- Don't mix bare arrays and enveloped responses — bare top-level arrays are harder to evolve (you can't add metadata later without a breaking change). Prefer `{ items: [...] }`.

## 6. Naming & casing

- **Pick one case for JSON field names and be consistent** — `camelCase` (Google, Microsoft) and `snake_case` (Stripe, GitHub) are both valid; mixing is a blocker.
- No abbreviations unless universal (`id`, `url`, `ip`). No `usr`, `prj`, `desc`, `cnt`.
- Boolean fields: positive form, `is`/`has`/`can` prefix. `isActive`, not `active` alone or `notActive`.
- Date fields: suffix with `At` or `Date`. `createdAt`, `dueDate`. ISO 8601 strings (or RFC 3339).
- Enum values: `SCREAMING_SNAKE_CASE` is the cross-language safe default (works in JSON, protobuf, most codegens).
- Consistent pluralization: `tags: [...]`, not `tagList` or `tag_array`.
- Don't leak implementation: `mongoId`, `tableRow`, `rowVersion` are smells.

## 7. Data types & validation

- Use the narrowest type that works. `integer` with `format: int64` for IDs > 2^31, not `string` unless the ID is truly non-numeric.
- Avoid `number` without `format: float`/`double` — ambiguous.
- Money: string with explicit currency code, or an object `{ amount: string, currency: "USD" }`. Never a float.
- Timestamps: ISO 8601 / RFC 3339 with timezone (`2025-01-15T10:30:00Z`), not epoch unless documented.
- Durations: ISO 8601 duration (`PT5M`) or integer with an explicit unit suffix (`timeoutSeconds`).
- Use `enum` for fixed value sets. Enums should be **additively extensible** — document that clients must tolerate unknown values, or clients will break when you add a new one.
- Every field should have: type, description, example, and constraints (min/max, pattern, enum).
- `required` is explicit, not implicit from `nullable: false`. Required and nullable are orthogonal concepts.
- Avoid `oneOf` / discriminated unions without a `discriminator` — codegens produce awful output.

## 8. Error model

Use a single, consistent error schema across the whole API. RFC 7807 (`application/problem+json`) is a good default:

```json
{
  "type": "https://example.com/errors/validation",
  "title": "Validation failed",
  "status": 422,
  "detail": "email must be a valid email address",
  "instance": "/users",
  "errors": [
    { "field": "email", "code": "invalid_format", "message": "..." }
  ]
}
```

Check:

- Every operation documents its error responses (at minimum `400`, `401`, `403`, `404`, `5xx` where applicable).
- Error response schema is the same across operations (use a single `$ref`).
- Error codes are stable machine-readable strings (`USER_NOT_FOUND`), not ad-hoc numbers or prose.
- No stack traces or internal IDs in production error bodies.
- Field-level validation errors point at the field (`errors[].field` or JSON Pointer).

## 9. Pagination, filtering, sorting

**Pagination:**

- Cursor-based is preferred for large or changing datasets: `?pageSize=50&pageToken=abc`, response includes `nextPageToken`.
- Offset-based (`?offset=100&limit=50`) is fine for small, stable datasets.
- Never return an unbounded list. Always enforce and document a `pageSize` max.
- Be consistent across the whole API — don't mix cursor and offset pagination.

**Filtering:**

- Simple filters as query params: `?status=active&createdAfter=2025-01-01`.
- Complex filters: consider a structured filter parameter (`?filter=status:active AND createdAt>2025-01-01`) documented with a grammar, not free-form.
- Don't expose SQL directly.

**Sorting:**

- `?orderBy=createdAt desc` (Google AIP-132) or `?sort=-createdAt,+name`. Pick one syntax and document it.

## 10. Versioning & evolvability

- Path versioning (`/v1/users`) is the most common; header versioning works but tooling is poorer.
- A released version is frozen for breaking changes. Additions are allowed; removals, renames, type changes, tightening validation, changing required-ness are **breaking** and must be a new version.
- Deprecation path: mark `deprecated: true` in OpenAPI, add `Sunset` / `Deprecation` headers (RFC 8594), document replacement in description.
- Never remove a field to "clean up" — that breaks clients. Add a new field and deprecate the old one.
- Additive changes: new optional fields, new endpoints, new optional query params, new enum values **if clients are documented to tolerate them**.

## 11. Security

- Define `securitySchemes` in OpenAPI and apply them per operation or globally. Don't rely on implicit auth.
- TLS required. Document HTTPS-only.
- Auth: OAuth 2.0 / OIDC for user-facing; API keys only for server-to-server or low-risk read endpoints.
- Rate limiting documented: include `X-RateLimit-*` headers in responses and `429` in error responses.
- No sensitive data in URLs (tokens, passwords, PII) — they end up in logs and referrers.
- Input validation: every string has `maxLength`, every array has `maxItems`, every number has bounds. Prevents DoS and injection.
- CORS policy is explicit.
- Write endpoints require authentication by default; document any public endpoints explicitly.

## 12. OpenAPI-specific hygiene

- Use `$ref` to share schemas in `components/schemas`. No duplicated inline schemas.
- Every operation has: `operationId` (unique, camelCase), `summary`, `description`, `tags`, and documented responses.
- `operationId` should be stable — it's used by codegens and changing it breaks clients.
- Tags are used to group operations logically (by resource, not by HTTP method).
- `servers` block present with production URL; no `localhost` in published specs.
- Examples provided on request/response bodies and parameters.
- No `additionalProperties: true` on request bodies by default — lets clients send unknown fields that silently fail.
- No mixing of OpenAPI 2 and 3 features; pick one spec version.
- Spec file is valid — if `swagger-cli validate` or equivalent fails, that's a blocker regardless of design.
