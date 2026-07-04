---
name: sync-upstream
description: Sync ImmichFrame's main branch with upstream (immichFrame/ImmichFrame), then preview or apply merging main into personal-main. Use when asked to sync/update main with upstream, catch up personal-main, or check for merge conflicts between them.
---

Syncs the `ImmichFrame` submodule's `main` branch with `upstream/main`
(`https://github.com/immichFrame/ImmichFrame`), then previews — or, with
`--apply`, actually performs — merging `main` into `personal-main`, the
user's permanent branch for personal features that weren't accepted
upstream (see `if-rahmen/CLAUDE.md` and project memory: never merge
`personal-main` *into* `main`/upstream, and never delete it).

All paths below are relative to `if-rahmen/` (the workspace root), not
to this skill directory.

## Run (agent path)

```bash
.claude/skills/sync-upstream/sync-upstream.sh              # sync main, dry-run merge preview (safe, default)
.claude/skills/sync-upstream/sync-upstream.sh --apply       # sync main, then really merge into personal-main
.claude/skills/sync-upstream/sync-upstream.sh --repo path   # override the ImmichFrame checkout path (default: ImmichFrame)
```

Default (no `--apply`) is always safe to run: it fetches, fast-forwards
or merges `upstream/main` into `main` locally (never pushes), then
previews the `main` → `personal-main` merge on a disposable scratch
branch/worktree that is deleted afterward — `personal-main` and its
worktree are never touched in this mode. Exit code 0 on success,
`2` if a conflict was found/hit (message printed either way — this is
informational, not necessarily a failure of the script itself).

`--apply` performs the real merge into `personal-main`'s actual
worktree. If it conflicts, the script stops and leaves the conflict
markers in place in `.worktree/personal-main/` for manual resolution —
it never auto-resolves, never force-picks a side, and never pushes.

## Gotchas

- **`main` is not a clean mirror of upstream.** As of 2026-07-04 it
  already carries 6 commits beyond `upstream/main`, including a
  `feat: add chronological slideshow grouping` implementation merged via
  a PR named `copilot/merge-main-into-personal-main` — its own commit
  message says it was meant to update `personal-main`, but landed on
  `main` instead. This means `main` and `personal-main` currently have
  **two independent implementations of chronological-slideshow
  grouping**, which is the single biggest source of merge conflicts
  between them (`ChronologicalAssetsPoolWrapper.cs`,
  `PooledImmichFrameLogic.cs`, `MultiImmichFrameLogicDelegate.cs`, and
  their tests all show up in the conflict list). Don't be surprised
  when these are what conflicts — that's the known, expected hotspot,
  not a bug in this skill.
- **`personal-main`'s worktree can go dangling.** If someone deletes
  `.worktree/personal-main` directly instead of running
  `git worktree remove`, git still thinks the branch is checked out
  there. `--apply` mode detects this (`ensure_worktree` in the script)
  and prunes the stale registration before recreating the worktree.
  Dry-run mode sidesteps this entirely by using its own scratch
  worktree instead of touching `.worktree/personal-main`.
- **Nothing is ever pushed automatically**, on either branch, in either
  mode — the script always prints the exact `git push` command to run
  yourself after reviewing the result.
- The dry-run's scratch branch is named `sync-preview/<epoch>` and its
  scratch worktree lives at `../.sync-preview-$$` (sibling of `ImmichFrame/`,
  auto-removed on exit, including on conflict).

## Troubleshooting

- `error: '<repo>' has uncommitted changes on main` — commit or stash
  in the `ImmichFrame` checkout before running; the script refuses to
  merge upstream into a dirty `main`.
- `CONFLICT merging upstream/main into main` — real upstream/fork
  divergence on `main` itself (distinct from the `main`→`personal-main`
  hotspot above). Resolve in `ImmichFrame/`, commit, then re-run.
- `CONFLICT merging main into personal-main` (from `--apply`) — resolve
  in `.worktree/personal-main/`, `git add` the resolved files, then
  `git commit` to complete the merge. The script does not retry or
  auto-commit for you.
- If `--apply` reports the worktree was "recreated," that's expected
  self-healing of the dangling-worktree state described above, not an
  error.

## Verified

Dry-run mode was run for real against this repo on 2026-07-04: `main`
was confirmed 0 behind / 6 ahead of `upstream/main` (no-op sync),
`personal-main` was confirmed 197 behind / 28 ahead of `main`, and the
merge preview correctly identified 22 real conflicting files without
touching `personal-main` or leaving any scratch branch/worktree behind.
`--apply` mode's real-merge path was not executed (by design — see
project decision to keep this a dry-run-first skill).
