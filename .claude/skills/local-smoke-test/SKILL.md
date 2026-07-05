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

## Verified

Both modes were run for real against this repo on 2026-07-05.

**Rebuild-and-test:** `smoke-test.sh rebuild-up` built the image (fully
Docker-layer-cached, ~2s) and reported "ImmichFrame is up and responding on
http://localhost:2284". Browser checks against that URL with the Playwright
MCP tools found: the page loaded real content (photo date `2019/05/12`,
clock, and live weather for Usingen — "Überwiegend bewölkt", 22.9°C —
confirming the configured Immich backend at `192.168.176.224:2283` and the
OpenWeatherMap key were both actually reachable from inside the container,
not just a blank/error screen); `browser_console_messages` showed 0 errors
and 1 warning (a benign deprecated-meta-tag notice,
`apple-mobile-web-app-capable`, plus a "PWA service worker registered" log)
— no error-level entries at all; `browser_network_requests` showed 45
requests, all `200 OK` (page shell, JS/CSS chunks, `/api/Config`,
`/api/Weather`, `/api/Calendar`, `/api/Asset`, several
`/api/Asset/<id>/Asset` and `/api/Asset/<id>/AssetFaces` calls, and `blob:`
URLs for the rendered images), no 4xx/5xx and nothing failed outright. Read
`Config-IF/Settings.yml` at run time: `Interval: 15`, `TransitionDuration: 3`,
so waited 15 + 3 + 5 = **23 seconds**, then took a second snapshot: the
photo date changed from `2019/05/12` to `2013/05/11`, new asset IDs
(`716f39b5…`, `5d05a9ee…`, `43d98948…`, `27db6f5b…`) and new `blob:` URLs
appeared in the network log, and the image elements' accessibility refs
changed (`e8`/`e14` → `e103`/`e109`) — the slideshow had genuinely advanced,
not stalled. Console/network state after the wait was unchanged (still 0
errors, all 200s). `smoke-test.sh down` afterward stopped and removed the
container and network cleanly.

**Test-as-is (failure path):** with `docker compose ps` confirming no
containers running, `smoke-test.sh check` exited 1 with `error: nothing
responding on http://localhost:2284. Did you mean 'rebuild-up'?` — the
expected refusal when nothing is up.

One environment-specific note, not a bug in this skill or in ImmichFrame:
`Config-IF/Settings.yml`'s `Accounts` entry points at a real LAN Immich
server (`192.168.176.224:2283`) and a real weather API key, both of which
happened to be reachable during this run, so the smoke test exercised real
data end-to-end rather than hitting expected-noise connection failures. If
that backend is ever unreachable in a future run, expect `/api/Asset`-family
4xx/5xx or failed requests to show up legitimately — that would be an
environment condition to report, not a slideshow/skill defect.
