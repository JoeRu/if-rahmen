# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Meta-folder layout

`if-rahmen/` is the workspace root for the ImmichFrame project, and is itself a git repository — remote `origin` at `git@github.com:JoeRu/if-rahmen.git`. `ImmichFrame/` is registered as a **git submodule** inside it (see `.gitmodules`), pinned to a specific commit on the submodule's own `main` branch; the submodule keeps its own independent history/remotes, untouched by the outer repo.

```
if-rahmen/                # own git repo, origin: git@github.com:JoeRu/if-rahmen.git
├── ImmichFrame/           # git submodule — see "ImmichFrame/ (submodule)" below
├── .worktree/             # Git worktrees of the ImmichFrame repo (gitignored — see below)
│   ├── main-replay/       # currently checked out to branch restore-issue-638-main-replay (not main-replay — see gotcha below)
│   └── personal-main/     # Branch: personal-main — user's permanent personal-dev branch, never merge/delete
├── graphify-out/          # /graphify knowledge-graph outputs (tracked in the outer repo)
├── .claude/skills/        # local skills, e.g. sync-upstream (see below)
└── scripts/               # Helper scripts for this workspace (run from here)
```

For project-specific commands, architecture, and conventions see `ImmichFrame/CLAUDE.md`.

`.gitignore` at this level excludes `.worktree/`, `.claude/settings.local.json`, and `.claude/scheduled_tasks.lock` — all local/ephemeral state that shouldn't be versioned in the outer repo.

## ImmichFrame/ (submodule)

The primary working directory for day-to-day development, registered as a git submodule pointing at `https://github.com/JoeRu/ImmichFrame.git` (the user's fork). Its own remotes:
- `origin` → `https://github.com/JoeRu/ImmichFrame.git` (the fork)
- `upstream` → `https://github.com/immichFrame/ImmichFrame.git` (the mainline project)

Branches worth knowing:
- **`main`** — tracks `origin/main`. Not a clean mirror of upstream: it currently carries a few commits beyond `upstream/main`, including a chronological-slideshow-grouping implementation that landed here via a PR seemingly meant for `personal-main` (see `sync-upstream`'s SKILL.md Gotchas for the full story).
- **`personal-main`** — the user's **permanent** branch for personal features that weren't accepted upstream (e.g. chronological slideshow grouping, color-contrast/complementary-color picker work). **Never merge into `main`/upstream, never delete, never treat as stale/experimental** — it's intentionally a long-lived side branch.

Treat `ImmichFrame/` as the canonical source for builds, tests, and releases. Because it's a submodule, changes inside it are committed to *its own* history and only the pinned-commit gitlink is committed in the outer `if-rahmen` repo — bump that pin deliberately, don't let it drift silently.

## .worktree/ (gitignored, local-only)

Each subdirectory of `.worktree/` is a `git worktree` checkout of the ImmichFrame repo on a separate branch, sharing the same `.git` object store as `ImmichFrame/`. This directory is gitignored in the outer repo — worktrees are inherently local/ephemeral and stay wired to `ImmichFrame/.git` regardless of what the outer repo does.

**Conventions:**
- Create new worktrees with: `git -C ImmichFrame worktree add ../.worktree/<branch-name> <branch-name>`
- List active worktrees: `git -C ImmichFrame worktree list`
- Remove a worktree when done: `git -C ImmichFrame worktree remove ../.worktree/<branch-name>`
- Never manually delete a `.worktree/<name>` directory without running `worktree remove` first — it leaves dangling metadata in the git repo (git still thinks the branch is checked out there, blocking new checkouts of that branch, and `git worktree list` reports it `prunable`). If this happens, run `git -C ImmichFrame worktree remove <path>` (or `worktree prune`) to clear the stale registration before recreating it — the branch itself is safe as long as it's pushed to its remote.
- Worktrees that are no longer needed after merging should be cleaned up promptly.

**Active worktrees:**

| Folder | Branch actually checked out | Purpose |
|--------|------------------------------|---------|
| `.worktree/main-replay` | `restore-issue-638-main-replay` (note: **not** the `main-replay` branch, despite the folder name) | Personal patches on top of upstream — **preserve these commits** |
| `.worktree/personal-main` | `personal-main` | User's permanent personal-dev branch (chronological slideshow, color contrast, etc.) — **never merge into main/upstream, never delete** |

## .claude/skills/sync-upstream

Syncs `ImmichFrame`'s `main` with `upstream/main`, then previews (default, safe) or applies (`--apply`) merging `main` into `personal-main`. Never auto-resolves conflicts, never auto-pushes. See `.claude/skills/sync-upstream/SKILL.md` for full usage, gotchas, and the known chronological-slideshow conflict hotspot between `main` and `personal-main`.

## scripts/

Helper scripts for workspace-level tasks (syncing branches, bulk operations, etc.) live in `scripts/`. Run them from `if-rahmen/` unless a script's header says otherwise.
