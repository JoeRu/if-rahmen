#!/usr/bin/env bash
# Sync ImmichFrame's main branch with upstream/main, then preview or apply
# merging main into personal-main.
#
# Usage (run from if-rahmen/ root, or pass --repo):
#   .claude/skills/sync-upstream/sync-upstream.sh                 # sync main + dry-run merge preview
#   .claude/skills/sync-upstream/sync-upstream.sh --apply         # sync main + real merge into personal-main
#   .claude/skills/sync-upstream/sync-upstream.sh --repo path/to/ImmichFrame
#
# Never auto-resolves conflicts. Dry-run mode touches no real branch or
# worktree; --apply stops with the conflict in place for manual resolution
# and never auto-commits a conflicted merge.
set -euo pipefail

REPO="ImmichFrame"
APPLY=0
MAIN_BRANCH="main"
DEV_BRANCH="personal-main"
UPSTREAM_REMOTE="upstream"

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --repo) shift; REPO="$1" ;;
    --repo=*) REPO="${1#--repo=}" ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ ! -d "$REPO/.git" ]; then
  echo "error: '$REPO' is not a git repository (looked for $REPO/.git)" >&2
  exit 1
fi

log() { printf '\n=== %s ===\n' "$1"; }

log "Fetching $UPSTREAM_REMOTE and origin"
git -C "$REPO" fetch "$UPSTREAM_REMOTE"
git -C "$REPO" fetch origin

log "Syncing $MAIN_BRANCH with $UPSTREAM_REMOTE/$MAIN_BRANCH"
BEHIND=$(git -C "$REPO" rev-list --count "$MAIN_BRANCH".."$UPSTREAM_REMOTE/$MAIN_BRANCH")
AHEAD=$(git -C "$REPO" rev-list --count "$UPSTREAM_REMOTE/$MAIN_BRANCH".."$MAIN_BRANCH")
echo "$MAIN_BRANCH is $AHEAD commit(s) ahead and $BEHIND commit(s) behind $UPSTREAM_REMOTE/$MAIN_BRANCH"

if [ "$BEHIND" -eq 0 ]; then
  echo "Nothing to sync from upstream right now."
else
  CURRENT_BRANCH=$(git -C "$REPO" branch --show-current)
  if [ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]; then
    echo "error: '$REPO' has '$MAIN_BRANCH' checked out only via a worktree or a different branch is active ($CURRENT_BRANCH)." >&2
    echo "This script expects '$MAIN_BRANCH' to be the active checkout in '$REPO' (it normally is)." >&2
    exit 1
  fi
  if ! git -C "$REPO" diff --quiet || ! git -C "$REPO" diff --cached --quiet; then
    echo "error: '$REPO' has uncommitted changes on $MAIN_BRANCH — commit or stash before syncing." >&2
    exit 1
  fi
  echo "Merging $UPSTREAM_REMOTE/$MAIN_BRANCH into $MAIN_BRANCH..."
  if git -C "$REPO" merge --ff-only "$UPSTREAM_REMOTE/$MAIN_BRANCH" 2>/dev/null; then
    echo "Fast-forwarded $MAIN_BRANCH to $UPSTREAM_REMOTE/$MAIN_BRANCH."
  else
    if git -C "$REPO" merge --no-ff "$UPSTREAM_REMOTE/$MAIN_BRANCH" -m "Merge $UPSTREAM_REMOTE/$MAIN_BRANCH into $MAIN_BRANCH"; then
      echo "Merged $UPSTREAM_REMOTE/$MAIN_BRANCH into $MAIN_BRANCH."
    else
      echo "" >&2
      echo "CONFLICT merging $UPSTREAM_REMOTE/$MAIN_BRANCH into $MAIN_BRANCH. Resolve manually:" >&2
      git -C "$REPO" diff --name-only --diff-filter=U | sed 's/^/  - /' >&2
      echo "Not pushed. Resolve, commit, then re-run this script or push manually." >&2
      exit 2
    fi
  fi
  echo "NOTE: $MAIN_BRANCH was updated locally but NOT pushed to origin — review and push yourself:"
  echo "  git -C $REPO push origin $MAIN_BRANCH"
fi

# --- Ensure the personal-main worktree registration matches disk reality ---
ensure_worktree() {
  local branch="$1" path="$2"
  local registered
  registered=$(git -C "$REPO" worktree list --porcelain | awk -v b="refs/heads/$branch" '
    /^worktree /{p=$2} /^branch /{if ($2==b) print p}')
  if [ -n "$registered" ] && [ ! -d "$registered" ]; then
    echo "Worktree for '$branch' is registered at '$registered' but missing on disk — pruning stale entry."
    git -C "$REPO" worktree remove --force "$registered" 2>/dev/null || git -C "$REPO" worktree prune
  fi
}

log "Previewing merge of $MAIN_BRANCH into $DEV_BRANCH"
DEV_BEHIND=$(git -C "$REPO" rev-list --count "$DEV_BRANCH".."$MAIN_BRANCH")
DEV_AHEAD=$(git -C "$REPO" rev-list --count "$MAIN_BRANCH".."$DEV_BRANCH")
echo "$DEV_BRANCH is $DEV_AHEAD commit(s) ahead and $DEV_BEHIND commit(s) behind $MAIN_BRANCH"

if [ "$DEV_BEHIND" -eq 0 ]; then
  echo "$DEV_BRANCH already contains all of $MAIN_BRANCH. Nothing to merge."
  exit 0
fi

if [ "$APPLY" -eq 0 ]; then
  echo "Dry run: attempting the merge on a scratch branch (no changes to $DEV_BRANCH or its worktree)."
  SCRATCH="sync-preview/$(date +%s 2>/dev/null || echo tmp)"
  git -C "$REPO" branch "$SCRATCH" "$DEV_BRANCH"
  set +e
  git -C "$REPO" -c core.editor=true worktree add --quiet "../.sync-preview-$$" "$SCRATCH" >/dev/null 2>&1
  PREVIEW_DIR="../.sync-preview-$$"
  git -C "$REPO/$PREVIEW_DIR" merge --no-ff "$MAIN_BRANCH" -m "preview: merge $MAIN_BRANCH into $DEV_BRANCH" >/tmp/sync-preview.log 2>&1
  MERGE_RC=$?
  set -e
  if [ $MERGE_RC -eq 0 ]; then
    echo "Clean merge possible: no conflicts between $MAIN_BRANCH and $DEV_BRANCH."
  else
    echo ""
    echo "This merge WILL conflict. Files:"
    git -C "$REPO/$PREVIEW_DIR" diff --name-only --diff-filter=U | sed 's/^/  - /'
  fi
  git -C "$REPO/$PREVIEW_DIR" merge --abort 2>/dev/null || true
  git -C "$REPO" worktree remove --force "$PREVIEW_DIR" 2>/dev/null || true
  git -C "$REPO" branch -D "$SCRATCH" >/dev/null
  echo ""
  echo "Dry run only — $DEV_BRANCH and its worktree were not touched."
  echo "Re-run with --apply to perform the real merge (conflicts, if any, are left for you to resolve)."
  exit 0
fi

log "Applying merge of $MAIN_BRANCH into $DEV_BRANCH"
WORKTREE_PATH="../.worktree/$DEV_BRANCH"
ensure_worktree "$DEV_BRANCH" "$WORKTREE_PATH"
if [ ! -d "$REPO/$WORKTREE_PATH" ]; then
  echo "Recreating missing worktree at $WORKTREE_PATH"
  git -C "$REPO" worktree add "$WORKTREE_PATH" "$DEV_BRANCH"
fi

if ! git -C "$REPO/$WORKTREE_PATH" diff --quiet || ! git -C "$REPO/$WORKTREE_PATH" diff --cached --quiet; then
  echo "error: $DEV_BRANCH worktree has uncommitted changes — commit or stash before merging." >&2
  exit 1
fi

set +e
git -C "$REPO/$WORKTREE_PATH" merge --no-ff "$MAIN_BRANCH" -m "Merge $MAIN_BRANCH into $DEV_BRANCH"
MERGE_RC=$?
set -e
if [ $MERGE_RC -eq 0 ]; then
  echo "Merged $MAIN_BRANCH into $DEV_BRANCH cleanly. NOT pushed — review, then:"
  echo "  git -C $REPO/$WORKTREE_PATH push origin $DEV_BRANCH"
else
  echo "" >&2
  echo "CONFLICT merging $MAIN_BRANCH into $DEV_BRANCH. Left unresolved in $REPO/$WORKTREE_PATH:" >&2
  git -C "$REPO/$WORKTREE_PATH" diff --name-only --diff-filter=U | sed 's/^/  - /' >&2
  echo "Resolve there, then 'git add' + 'git commit' to complete the merge. Nothing was pushed." >&2
  exit 2
fi
