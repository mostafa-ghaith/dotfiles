# Skills I had (snapshot 2026-06-27)

These were the custom skills present before simplifying the sync setup. The repo
**no longer syncs skills** — reinstall the ones you want manually into
`~/.claude/skills/` (each is a folder containing a `SKILL.md`).

The actual content of all of these is still on this machine at
**`~/.agents/skills/`** (and in the `~/claude-backups/` snapshot), so you can copy
any of them straight over if you want it back:

```bash
cp -R ~/.agents/skills/<name> ~/.claude/skills/<name>
```

## Matt Pocock engineering skills
Origin: the "engineering skills" set (install/refresh via the `setup-matt-pocock-skills`
flow, or copy from `~/.agents/skills/`).

| Skill | What it does |
|---|---|
| ask-matt | Router that points you to the right skill/flow for your situation |
| codebase-design | Shared vocabulary for designing deep modules |
| decision-mapping | Turn a loose idea into a sequenced map of investigation tickets |
| design-an-interface | Generate radically different interface designs via parallel sub-agents |
| diagnosing-bugs | Diagnosis loop for hard bugs and performance regressions |
| domain-modeling | Build and sharpen a project's domain model |
| edit-article | Edit/improve articles — restructure, clarify, tighten prose |
| git-guardrails-claude-code | Hooks to block dangerous git commands (push, reset --hard, clean, branch -D) |
| grill-me | Relentless interview to sharpen a plan or design |
| grill-with-docs | Grilling that also produces ADRs and a glossary |
| grilling | Stress-test a plan or design by relentless interview |
| handoff | Compact the conversation into a handoff doc for another agent |
| implement | Implement work based on a PRD or set of issues |
| improve-codebase-architecture | Scan for deepening opportunities, report as HTML, then grill |
| migrate-to-shoehorn | Migrate test `as` assertions to @total-typescript/shoehorn |
| obsidian-vault | Search/create/manage Obsidian notes with wikilinks |
| prototype | Build a throwaway runnable prototype to flesh out a design |
| qa | Conversational QA session that files GitHub issues |
| request-refactor-plan | Create a tiny-commit refactor plan, file it as a GitHub issue |
| resolving-merge-conflicts | Resolve an in-progress git merge/rebase conflict |
| review | Review changes since a fixed point along Standard/… axes |
| scaffold-exercises | Create exercise dir structures (sections/problems/solutions) |
| setup-matt-pocock-skills | Configure a repo for the engineering skills (tracker, labels…) |
| setup-pre-commit | Husky pre-commit hooks: lint-staged, type check, tests |
| tdd | Test-driven development workflow |
| teach | Teach a new skill/concept within the workspace |
| to-issues | Break a plan/spec/PRD into grabbable tracker issues |
| to-prd | Turn the conversation into a PRD and publish it |
| triage | Move issues/PRs through a triage state machine |
| ubiquitous-language | Extract a DDD ubiquitous-language glossary |
| writing-beats | Shape an article as a journey of beats |
| writing-fragments | Mine the user for writing fragments via grilling |
| writing-great-skills | Reference for writing/editing skills well |
| writing-shape | Shape raw markdown into an article conversationally |

## Frontend / design skills
Origin: standalone (copy from `~/.agents/skills/`).

| Skill | What it does |
|---|---|
| design-taste-frontend | Anti-slop frontend skill for landing pages, portfolios, redesigns |
| gpt-taste | UX/UI + GSAP motion; Python-driven layout randomization |
| high-end-visual-design | Design like a high-end agency (fonts, spacing, shadows, cards) |

## My own / project skills
| Skill | What it does |
|---|---|
| api-schema-reviewer | Review API schema designs (OpenAPI/REST, GraphQL, gRPC) vs best practices |
| langgraph-agent-development | LangGraph agent development helper |

## Discovery / external
| Skill | What it does | Note |
|---|---|---|
| find-skills | Discover & install agent skills on demand | |
| langfuse | Langfuse skill | External source `langfuse-skills` repo; was a symlink to a path that no longer exists — reinstall from source if needed |
