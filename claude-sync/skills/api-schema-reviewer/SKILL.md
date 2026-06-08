---
name: api-schema-reviewer
description: Review API schema designs (OpenAPI/REST, GraphQL, gRPC/protobuf) against industry best practices and produce a structured, severity-ranked report. Use when the user asks to review, audit, or critique an API schema, OpenAPI/Swagger spec, GraphQL SDL, proto file, or API design doc; when evaluating a new endpoint/resource; or when checking an API for consistency, backwards compatibility, naming, error modeling, pagination, versioning, or security concerns.
---

# API Schema Reviewer

Review API schema definitions and produce a structured report of findings tied to specific schema locations, ranked by severity. This skill guides a consistent, rigorous review grounded in widely-accepted best practices (Google API Design Guide / AIPs, Microsoft REST API Guidelines, Zalando RESTful Guidelines, GraphQL best practices, protobuf style guide).

## Workflow

Follow these steps in order.

### 1. Identify the schema type

Detect the style from file extension and content:

- **OpenAPI/REST** — `.yaml`/`.yml`/`.json` with `openapi:` or `swagger:` at the top, or a REST API design doc
- **GraphQL** — `.graphql`/`.gql` SDL files, or inline `type Query { ... }` blocks
- **gRPC/protobuf** — `.proto` files with `syntax = "proto3";` (or proto2)
- **JSON Schema (standalone)** — files with `$schema` referring to json-schema.org; treat as data model review using the REST reference

If unclear, ask the user. If multiple are present (e.g., a monorepo), ask which to review first.

### 2. Load the matching reference

Read **only** the reference(s) matching the detected style — not all of them:

- OpenAPI/REST → [references/rest-openapi.md](references/rest-openapi.md)
- GraphQL → [references/graphql.md](references/graphql.md)
- gRPC/protobuf → [references/grpc.md](references/grpc.md)

Also read [references/common-pitfalls.md](references/common-pitfalls.md) — it covers cross-cutting concerns (naming, security, errors, evolvability) that apply to all API styles.

### 3. Read the schema in full

Read the entire schema file(s) before writing any findings. Do not review a spec you have only partially read — cross-cutting issues (shared models, consistency, naming patterns) require whole-schema context.

For very large specs (>2000 lines), read in chunks, but complete the full pass before drafting findings.

### 4. Collect findings

For each issue found, capture:

- **Location** — exact schema path (e.g., `paths./users.post.requestBody.content.application/json.schema.properties.email`, GraphQL `type User.field email`, or proto `message User.field email`)
- **Severity** — one of:
  - `blocker` — ships broken, unsafe, or a breaking change with no migration path
  - `major` — violates a core best practice, will cause real pain for clients or future maintainers
  - `minor` — noticeable inconsistency, suboptimal modeling, or missing non-critical detail
  - `nit` — stylistic or subjective preference
- **Category** — e.g., `naming`, `http-semantics`, `error-model`, `pagination`, `versioning`, `security`, `data-model`, `documentation`, `backwards-compat`, `consistency`
- **Finding** — one sentence stating what's wrong
- **Why it matters** — one sentence on the concrete consequence
- **Suggested fix** — concrete, copy-pasteable when possible

Be specific. "Naming is inconsistent" is not a finding; "`user_id` (snake_case) at `paths./users/{user_id}` conflicts with `createdAt` (camelCase) at `components.schemas.User.createdAt`" is.

### 5. Produce the report

Write the report to the user using the template at [assets/review-report-template.md](assets/review-report-template.md). Render it inline in the conversation unless the user asks for a file.

Order findings by severity (blocker → nit), and within a severity group by category.

### 6. Summary section

End with a short summary:

- Count of findings per severity
- Top 3 themes (e.g., "inconsistent casing throughout", "missing error responses on all mutations")
- A one-sentence verdict: ship-ready, needs revisions before merge, or needs significant rework

## Review principles

These apply to every review, regardless of style:

1. **Evidence over opinion.** Every finding points at a specific schema location. No vague "this feels off".
2. **Severity discipline.** A `blocker` must genuinely block. If everything is a blocker, nothing is. When in doubt, downgrade.
3. **Consistency beats correctness at the margin.** If the schema consistently uses a non-preferred pattern (e.g., snake_case throughout), flag it once as a convention choice — don't flag every occurrence. Changing half is worse than either pattern alone.
4. **Backwards compatibility is paramount** for any schema marked as released / v1+. Flag breaking changes as `blocker` unless the user has explicitly stated this is a new major version.
5. **Silence is fine.** If a section is well-designed, don't manufacture findings. Say so briefly in the summary.
6. **Separate "wrong" from "different".** Many choices are taste (PATCH vs PUT semantics, envelope vs bare responses, cursor vs offset pagination). Flag as `nit` with the alternative noted; don't insist.

## When the user provides a PR or diff

If reviewing changes (not a full schema):

1. Still read the full surrounding schema for context — a field rename looks fine in isolation and catastrophic in context.
2. Pay special attention to backwards compatibility: removed fields, changed types, tightened validation, changed required-ness, renamed enums, reused proto field numbers.
3. State explicitly in the summary whether the change is backwards-compatible.

## What NOT to do

- Don't rewrite the schema. Suggest fixes in findings; let the user apply them.
- Don't lecture. Keep "why it matters" to one sentence.
- Don't flag every missing description as a separate finding. Group them: "27 operations are missing descriptions; see [list]".
- Don't invoke external validators or linters unless the user asks — this skill is about design review, not lint.
