# Local Smoke Test Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `local-smoke-test` Claude Code skill that verifies the local ImmichFrame docker-compose deployment actually works (page loads, no console errors, no failed network requests, slideshow advances), in either a rebuild-and-test mode or a test-as-is mode.

**Architecture:** A bash helper script (`smoke-test.sh`) owns the docker-compose lifecycle only (`check` / `rebuild-up` / `down` subcommands, run from the workspace root next to `docker-compose.yml`). A `SKILL.md` instructs the agent to call the right subcommand via Bash, then drive the browser directly via the already-installed Playwright MCP tools (navigate, console messages, network requests, snapshots), then report a PASS/FAIL summary in chat. No new dependency is installed; nothing is persisted to disk beyond the two skill files.

**Tech Stack:** bash (`set -euo pipefail`, matching `.claude/skills/sync-upstream/sync-upstream.sh`'s style), `docker compose`, `curl`, the Playwright MCP plugin already present in this environment (`mcp__plugin_playwright_playwright__*` tools).

## Global Constraints

- Exactly two trigger modes: rebuild-and-test, and test-as-is. No CI/headless mode, no third mode.
- No persisted report file — findings are reported in chat only.
- The skill must never modify `docker-compose.yml` or anything under `Config-IF/`.
- In rebuild-and-test mode, `smoke-test.sh down` runs afterward unconditionally — pass or fail.
- `smoke-test.sh` is run from the workspace root (`if-rahmen/`), matching `sync-upstream.sh`'s convention of being invoked relative to the workspace root rather than resolving its own location.
- Follow `.claude/skills/sync-upstream/`'s file layout convention: folder name equals skill name, `SKILL.md` has `name:` + `description:` frontmatter, a `## Verified` section is added once the skill has actually been run for real.

---

### Task 1: `smoke-test.sh` docker-compose lifecycle script

**Files:**
- Create: `.claude/skills/local-smoke-test/smoke-test.sh`

**Interfaces:**
- Produces: three subcommands invoked as `.claude/skills/local-smoke-test/smoke-test.sh <check|rebuild-up|down>`.
  - `check`: exit 0 and print `"ImmichFrame is responding on http://localhost:<PORT>"` if something already answers on the compose-file's mapped host port; otherwise exit 1 with `"error: nothing responding on http://localhost:<PORT>. Did you mean 'rebuild-up'?"` on stderr. Runs no docker commands.
  - `rebuild-up`: `docker compose build && docker compose up -d`, then poll the same host port for up to 90s; exit 0 and print `"ImmichFrame is up and responding on http://localhost:<PORT>"` on success, or exit 1 with the last 50 lines of `docker compose logs` on stderr if it times out.
  - `down`: `docker compose down`.

- [ ] **Step 1: Write the script**

```bash
mkdir -p .claude/skills/local-smoke-test
```

Create `.claude/skills/local-smoke-test/smoke-test.sh`:

```bash
#!/usr/bin/env bash
# Local smoke-test docker-compose lifecycle helper.
#
# Usage (run from if-rahmen/ root, next to docker-compose.yml):
#   .claude/skills/local-smoke-test/smoke-test.sh check        # fail fast if nothing is already running
#   .claude/skills/local-smoke-test/smoke-test.sh rebuild-up   # docker compose build && up -d, wait for readiness
#   .claude/skills/local-smoke-test/smoke-test.sh down         # docker compose down
#
# Owns the container lifecycle only — never touches a browser and never
# modifies docker-compose.yml or Config-IF/.
set -euo pipefail

if [ ! -f docker-compose.yml ]; then
  echo "error: docker-compose.yml not found in the current directory — run this from the if-rahmen/ workspace root." >&2
  exit 1
fi

PORT=$(grep -oE '"[0-9]+:[0-9]+"' docker-compose.yml | head -1 | tr -d '"' | cut -d: -f1)
if [ -z "$PORT" ]; then
  PORT=2284
fi

wait_ready() {
  local timeout="$1" waited=0
  while ! curl -sf -o /dev/null "http://localhost:$PORT"; do
    if [ "$waited" -ge "$timeout" ]; then
      return 1
    fi
    sleep 2
    waited=$((waited + 2))
  done
  return 0
}

cmd="${1:-}"
case "$cmd" in
  check)
    if wait_ready 6; then
      echo "ImmichFrame is responding on http://localhost:$PORT"
      exit 0
    else
      echo "error: nothing responding on http://localhost:$PORT. Did you mean 'rebuild-up'?" >&2
      exit 1
    fi
    ;;
  rebuild-up)
    docker compose build
    docker compose up -d
    if wait_ready 90; then
      echo "ImmichFrame is up and responding on http://localhost:$PORT"
      exit 0
    else
      echo "error: container did not become ready within 90s. Recent logs:" >&2
      docker compose logs --tail=50 >&2
      exit 1
    fi
    ;;
  down)
    docker compose down
    ;;
  *)
    echo "Usage: $0 <check|rebuild-up|down>" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x .claude/skills/local-smoke-test/smoke-test.sh
```

- [ ] **Step 3: Verify `check` fails fast when nothing is running**

Run: `docker compose ps` first to confirm no `immichframe` container is up, then:

```bash
.claude/skills/local-smoke-test/smoke-test.sh check
```

Expected: exits 1, prints `error: nothing responding on http://localhost:2284. Did you mean 'rebuild-up'?` to stderr.

- [ ] **Step 4: Verify `rebuild-up` builds, starts, and waits for readiness**

Run:

```bash
.claude/skills/local-smoke-test/smoke-test.sh rebuild-up
```

Expected: docker build output, then `docker compose up -d` output, then `ImmichFrame is up and responding on http://localhost:2284`, exit 0.

- [ ] **Step 5: Verify `check` succeeds while it's running**

Run:

```bash
.claude/skills/local-smoke-test/smoke-test.sh check
```

Expected: `ImmichFrame is responding on http://localhost:2284`, exit 0.

- [ ] **Step 6: Verify `down` stops it and `check` fails again**

Run:

```bash
.claude/skills/local-smoke-test/smoke-test.sh down
.claude/skills/local-smoke-test/smoke-test.sh check
```

Expected: `docker compose down` output, then the `check` call exits 1 with the same "nothing responding" error as Step 3.

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/local-smoke-test/smoke-test.sh
git commit -m "Add smoke-test.sh docker-compose lifecycle helper for local-smoke-test skill"
```

---

### Task 2: `SKILL.md` agent instructions + real end-to-end verification

**Files:**
- Create: `.claude/skills/local-smoke-test/SKILL.md`
- Modify: `.claude/skills/local-smoke-test/SKILL.md` (append `## Verified` section after Step 3 below)

**Interfaces:**
- Consumes: `.claude/skills/local-smoke-test/smoke-test.sh check|rebuild-up|down` from Task 1.
- Consumes (environment): Playwright MCP tools already installed in this session — `mcp__plugin_playwright_playwright__browser_navigate`, `browser_console_messages`, `browser_network_requests`, `browser_snapshot`, `browser_close`.
- Produces: the `local-smoke-test` skill, invoked by name, with no further interfaces consumed by other tasks (this is the last task).

- [ ] **Step 1: Write `SKILL.md`**

Create `.claude/skills/local-smoke-test/SKILL.md`:

```markdown
---
name: local-smoke-test
description: Smoke-test the local ImmichFrame docker-compose deployment (docker-compose.yml + Config-IF/) by loading it in a real browser and checking for console errors, failed network requests, and a stuck slideshow. Use when asked to smoke-test, sanity-check, or verify the local ImmichFrame instance works, either after rebuilding it or against whatever is already running.
---

Verifies the local ImmichFrame deployment actually works: the page loads,
no console errors, no failed network requests, and the slideshow advances.
Meant as a fast dev-loop check, not a CI-grade test suite. Never writes a
report file — findings are reported in chat.

All paths below are relative to `if-rahmen/` (the workspace root), not to
this skill directory.

## Mode selection

- If the user asks to rebuild, or to test the result of a change you just
  built/merged, use **rebuild-and-test**.
- If the user just asks to "check" or "smoke-test" the local instance with
  no mention of rebuilding, default to **test-as-is** (the less destructive
  option) — it does not touch the container lifecycle at all.

## Test-as-is mode

```bash
.claude/skills/local-smoke-test/smoke-test.sh check
```

If this exits non-zero, stop and report the error — nothing is running to
test. Otherwise continue to "Browser checks" below.

## Rebuild-and-test mode

```bash
.claude/skills/local-smoke-test/smoke-test.sh rebuild-up
```

If this exits non-zero, stop and report the build/startup error (it prints
the last 50 lines of `docker compose logs`) — do not proceed to browser
checks against a dead target, and skip straight to running
`.claude/skills/local-smoke-test/smoke-test.sh down` before reporting.

Otherwise continue to "Browser checks" below, and **always** run
`.claude/skills/local-smoke-test/smoke-test.sh down` afterward, regardless
of whether the browser checks below pass or fail.

## Browser checks

Drive these directly with the Playwright MCP tools — do not write a script
for this part.

1. `browser_navigate` to `http://localhost:2284` (or whichever port
   `smoke-test.sh` reported). Take a `browser_snapshot` — confirm it shows
   real page content, not a blank page or an error screen.
2. Call `browser_console_messages` — flag any entries at `error` level.
3. Call `browser_network_requests` — flag any request with a 4xx/5xx status
   or that failed outright.
4. Note the current image/video element's `src` from the snapshot. Read
   `Interval` and `TransitionDuration` from `Config-IF/Settings.yml`'s
   `General:` section (default to 15 and 3 respectively if either key is
   absent or commented out). Wait `Interval + TransitionDuration + 5`
   seconds, then take another `browser_snapshot` and compare the image/video
   element's `src`. If it's unchanged, flag a stuck slideshow.
5. Call `browser_close` to end the session.

## Reporting

Report one PASS/FAIL summary in chat, with a bullet for each check
(page load, console errors, network requests, slideshow advance) and the
specific detail for anything flagged (the console message text, the failed
request's URL and status, or "slideshow did not advance after Ns"). Do not
write a report file.
```

- [ ] **Step 2: Run the full rebuild-and-test flow for real**

```bash
.claude/skills/local-smoke-test/smoke-test.sh rebuild-up
```

Expected: same as Task 1 Step 4 (`ImmichFrame is up and responding on http://localhost:2284`).

Then use the Playwright MCP tools directly, following the "Browser checks"
section just written, against `http://localhost:2284`:

- `mcp__plugin_playwright_playwright__browser_navigate` to `http://localhost:2284`
- `mcp__plugin_playwright_playwright__browser_snapshot`
- `mcp__plugin_playwright_playwright__browser_console_messages`
- `mcp__plugin_playwright_playwright__browser_network_requests`
- wait `Interval + TransitionDuration + 5` seconds (read the actual values out
  of `Config-IF/Settings.yml` at the time of this run), then
  `mcp__plugin_playwright_playwright__browser_snapshot` again and compare
- `mcp__plugin_playwright_playwright__browser_close`

Then:

```bash
.claude/skills/local-smoke-test/smoke-test.sh down
```

Record what actually happened (page loaded or not, any console errors seen,
any failed requests seen, whether the slideshow advanced) — this is the
content for Step 3's `## Verified` section, not a placeholder.

- [ ] **Step 3: Run the test-as-is failure path for real**

With nothing running (confirm via `docker compose ps`), run:

```bash
.claude/skills/local-smoke-test/smoke-test.sh check
```

Expected: exits 1 with the "nothing responding" error, confirming test-as-is
mode correctly refuses to proceed when the container isn't up.

- [ ] **Step 4: Append the `## Verified` section to `SKILL.md`**

Append a section to `.claude/skills/local-smoke-test/SKILL.md`, filled in
with the real results from Steps 2 and 3 (dates, what was actually observed
— e.g. whether console errors or failed requests showed up, whether the
slideshow advanced, how long the rebuild took), matching the style of the
`## Verified` section in `.claude/skills/sync-upstream/SKILL.md`.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/local-smoke-test/SKILL.md
git commit -m "Add SKILL.md for local-smoke-test, verified against the real local stack"
```
