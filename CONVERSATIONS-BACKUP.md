# Conversation backups

Old Claude conversations are **not** synced by this repo (they're machine-local,
huge, and conflict-prone). A one-time snapshot was taken on **2026-06-27** before
simplifying the setup.

## Location (this machine — NOT in this repo)

```
~/claude-backups/conversations-2026-06-27/
├── default-claude/     # from ~/.claude   (21 project folders, ~390M)
│   ├── projects/       # one folder per working dir, each holds *.jsonl transcripts
│   ├── sessions/
│   └── history.jsonl
└── account1/           # from ~/.claude-account1 (1 project folder)
    ├── projects/
    ├── sessions/
    ├── shell-snapshots/
    └── history.jsonl
```

Each `projects/<encoded-path>/` folder corresponds to a directory you ran Claude in
(e.g. `-Users-Mostafa-edecs-ai-...`). The `*.jsonl` files inside are the full
transcripts.

## How to recover a specific conversation

Just ask Claude, e.g.:

> "Go to `~/claude-backups/conversations-2026-06-27/` and find the conversation
> about <topic / which was in <project dir>, then copy it to <here>."

Or do it by hand:

```bash
ls ~/claude-backups/conversations-2026-06-27/default-claude/projects   # list project folders
grep -rl "some phrase" ~/claude-backups/conversations-2026-06-27        # find by content
```

## Notes
- This backup lives outside the repo on purpose — don't commit it (it's ~390M).
- `~/.claude-account1` was **deleted on 2026-06-27** after confirming its conversations
  were captured in this snapshot. Only the single default `~/.claude` remains.
