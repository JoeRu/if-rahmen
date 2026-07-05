# Local Smoke Test Skill — Design

## Purpose

A Claude Code skill that verifies the local ImmichFrame deployment (defined by
`docker-compose.yml` + `Config-IF/` at the workspace root) actually works: the
page loads, no console errors, no failed network requests, and the slideshow
advances. Meant as a fast dev-loop check — e.g. after building/merging
ImmichFrame changes locally, before pushing — not a CI-grade test suite.

## Scope

Two independent trigger modes:

1. **Rebuild-and-test** — rebuild the local docker image, start it, run the
   checks, tear it down.
2. **Test-as-is** — run the checks against whatever is already running on the
   configured port; do not manage the container lifecycle.

Out of scope: persisted report files, headless/CI-runnable execution (this
relies on the Playwright MCP plugin already installed in this environment, so
it only runs interactively inside Claude Code), and any change to
`docker-compose.yml` or `Config-IF/` itself.

## Components

### `.claude/skills/local-smoke-test/smoke-test.sh`

A bash helper that owns the docker-compose lifecycle only. It never touches a
browser. Subcommands:

- `check` — poll `http://localhost:<port>` (port read from
  `docker-compose.yml`'s `ports:` mapping, e.g. `2284`) for an HTTP response,
  up to a short timeout (e.g. 30s). Exit non-zero with a clear message if
  nothing responds ("nothing is running — did you mean `rebuild-up`?"). Runs
  no docker commands.
- `rebuild-up` — `docker compose build && docker compose up -d`, then poll the
  same readiness check with a longer timeout (e.g. 90s, to allow for image
  build/startup). Exit non-zero with the last docker-compose log output if it
  never becomes ready.
- `down` — `docker compose down`.

All commands run relative to the workspace root (`if-rahmen/`), matching the
`docker-compose.yml` location — the script should `cd` to its own parent's
grandparent (or otherwise resolve the workspace root) so it works regardless
of the caller's cwd.

### `.claude/skills/local-smoke-test/SKILL.md`

Instructions for the agent (not a script, since the browser is driven via
Playwright MCP tool calls, which are only invocable by the agent itself, not
from bash):

1. Determine mode from the user's request (default to `check` if ambiguous —
   the less destructive option).
2. Run the corresponding `smoke-test.sh` subcommand via Bash. If it fails,
   stop and report the failure — don't proceed to browser checks against a
   dead target.
3. Drive the browser directly via Playwright MCP tools:
   - `browser_navigate` to `http://localhost:<port>`.
   - `browser_snapshot` — confirm real content, not a blank/error page.
   - `browser_console_messages` — collect any `error`-level entries.
   - `browser_network_requests` — collect any 4xx/5xx or failed requests.
   - Record the current image/video element's `src` from the snapshot, wait
     slightly longer than `Interval + TransitionDuration` seconds (read from
     `Config-IF/Settings.yml`'s `General.Interval` /
     `General.TransitionDuration`; default to 15s + 3s if either key is
     absent), snapshot again, and compare `src` — flag if unchanged (stuck
     slideshow).
4. If the mode was `rebuild-up`, always run `smoke-test.sh down` afterward,
   regardless of whether prior steps passed or failed.
5. Report a single PASS/FAIL summary in chat with a bullet list of whatever
   was flagged (console errors, failed requests, page-load failure, stuck
   slideshow). No report file is written.

## Error Handling

Every browser-side check is "flag and continue," not "abort" — e.g. a blank
page is a finding to report, not a script crash, so the summary always covers
everything that was checked. `smoke-test.sh` is the only thing that hard-fails
(build/up erroring, readiness timeout), since there's no meaningful check to
continue with if the container never comes up.

## Testing

Manually run both modes once against the real local stack after
implementation:

- `rebuild-up` → checks → `down`, confirming teardown happens even by design
  after a passing run.
- `check` against an already-running container (started via `rebuild-up`
  without tearing down, for the purpose of this one verification run).
- `check` against nothing running, confirming the clear early error.

Record the outcome in the skill's `SKILL.md` under a `## Verified` section,
matching the convention used in `sync-upstream/SKILL.md`.
