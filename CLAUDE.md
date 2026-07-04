# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Meta-folder layout

`if-rahmen/` is the workspace root for the ImmichFrame project. It is **not** itself a git repository.

```
if-rahmen/
├── ImmichFrame/       # Primary git repo — upstream + personal changes
├── .worktree/         # Git worktrees of the ImmichFrame repo (see below)
│   ├── main-replay/   # Branch: main-replay — user's personal patches on top of upstream
│   └── personal-main/ # Branch: personal-main — experimental / WIP work
└── scripts/           # Helper scripts for this workspace (run from here)
```

For project-specific commands, architecture, and conventions see `ImmichFrame/CLAUDE.md`.

## ImmichFrame/

The primary working directory for day-to-day development. This is the main clone of the ImmichFrame git repo.

- Treat `ImmichFrame/` as the canonical source for builds, tests, and releases.
- The `main-replay` branch contains important personal changes that are **not** part of the upstream repo. Never overwrite, revert, or drop those commits accidentally.

## .worktree/

Each subdirectory of `.worktree/` is a `git worktree` checkout of the ImmichFrame repo on a separate branch. They share the same `.git` object store as `ImmichFrame/`.

**Conventions:**
- Create new worktrees with: `git -C ImmichFrame worktree add ../.worktree/<branch-name> <branch-name>`
- List active worktrees: `git -C ImmichFrame worktree list`
- Remove a worktree when done: `git -C ImmichFrame worktree remove ../.worktree/<branch-name>`
- Never manually delete a `.worktree/<name>` directory without running `worktree remove` first — it leaves dangling metadata in the git repo.
- Worktrees that are no longer needed after merging should be cleaned up promptly.

**Active worktrees:**

| Folder | Branch | Purpose |
|--------|--------|---------|
| `.worktree/main-replay` | `main-replay` | Personal patches on top of upstream — **preserve these commits** |
| `.worktree/personal-main` | `personal-main` | Experimental / in-progress work |

## scripts/

Helper scripts for workspace-level tasks (syncing branches, bulk operations, etc.) live in `scripts/`. Run them from `if-rahmen/` unless a script's header says otherwise.
