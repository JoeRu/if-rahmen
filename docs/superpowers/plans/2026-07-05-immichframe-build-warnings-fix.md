# ImmichFrame Build Warnings Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix three build-time warnings in ImmichFrame's frontend (a missing `svelte-kit sync` prepare step, and two Svelte 5 reactivity issues in `overlay-controls.svelte`/`overlay-qr.svelte`) on a new branch off `main`, verified against a real docker build and live browser check, ready to push and PR upstream.

**Architecture:** Three small, independent edits (one npm script, two one-line Svelte `$derived` changes) made in a new git worktree branched off `main` (which is currently identical to `upstream/main`). No Dockerfile or docker-compose.yml changes. Verification is manual (no frontend test framework exists in this project): `npm run check`/`npm run build` for the fast local check, then a real `docker build`+`docker run` plus Playwright MCP browser checks for live verification, including a check specific to the `overlay-qr.svelte` staleness bug.

**Tech Stack:** SvelteKit 2 / Svelte 5 (runes), Vite, npm, Docker, git worktrees, Playwright MCP tools.

## Global Constraints

- The affected files (`overlay-controls.svelte`, `overlay-qr.svelte`, `Dockerfile`) are byte-identical between the fork's `main` and `upstream/main` — already confirmed, not an action item, but it's why this targets `main`/upstream directly rather than `personal-main`.
- No changes to `Dockerfile` — the `prepare` script fix makes that unnecessary.
- No changes to `docker-compose.yml` or `Config-IF/` — live verification uses a standalone `docker build`/`docker run` against the worktree, not the shared compose stack.
- No changes to the fork's `personal-main` branch.
- No broader refactor of either `.svelte` file beyond the two specified `$derived` changes.
- Work happens in a new worktree at `.worktree/fix-build-warnings` on branch `fix-build-warnings`, branched from `main`. The primary `ImmichFrame/` checkout stays on `main`, untouched.
- **Pushing the branch to the fork and opening the PR is NOT part of either task below.** That is a visible, hard-to-reverse action the human controller confirms with the user directly after both tasks are reviewed and approved — no task or subagent should run `git push` or create a PR.

---

### Task 1: Implement the three fixes + fast local verification

**Files:**
- Create (worktree): `.worktree/fix-build-warnings/` (git worktree, branch `fix-build-warnings`, off `main`)
- Modify: `.worktree/fix-build-warnings/immichFrame.Web/package.json`
- Modify: `.worktree/fix-build-warnings/immichFrame.Web/src/lib/components/elements/overlay-controls.svelte`
- Modify: `.worktree/fix-build-warnings/immichFrame.Web/src/lib/components/elements/imageoverlay/overlay-qr.svelte`

**Interfaces:**
- Produces: a committed branch `fix-build-warnings` (not yet pushed) in the worktree at `if-rahmen/.worktree/fix-build-warnings`, with all three fixes applied and passing `npm run check`/`npm run build` with no `state_referenced_locally` or tsconfig warnings. Task 2 builds and runs this worktree via plain `docker build`/`docker run` (no docker-compose involvement).

- [ ] **Step 1: Create the worktree and branch**

```bash
cd C:\Users\johan\code\if-rahmen
git -C ImmichFrame fetch origin main
git -C ImmichFrame worktree add -b fix-build-warnings ../.worktree/fix-build-warnings main
```

Expected: `Preparing worktree (new branch 'fix-build-warnings')` followed by a checkout summary. Verify:

```bash
git -C ImmichFrame worktree list
```

Expected: a line for `.worktree/fix-build-warnings` showing `[fix-build-warnings]`.

- [ ] **Step 2: Fix the tsconfig warning — add the `prepare` script**

Open `.worktree/fix-build-warnings/immichFrame.Web/package.json`. Find the `scripts` block:

```json
	"scripts": {
		"dev": "vite dev",
		"build": "vite build",
		"preview": "vite preview",
		"check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
		"check:watch": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --watch",
		"lint": "prettier --check . && eslint .",
		"format": "prettier --write .",
		"api": "oazapfts ../openApi/swagger.json src/lib/immichFrameApi.ts"
	},
```

Replace it with (adds `"prepare"` after `"preview"`, nothing else changes):

```json
	"scripts": {
		"dev": "vite dev",
		"build": "vite build",
		"preview": "vite preview",
		"prepare": "svelte-kit sync",
		"check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
		"check:watch": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --watch",
		"lint": "prettier --check . && eslint .",
		"format": "prettier --write .",
		"api": "oazapfts ../openApi/swagger.json src/lib/immichFrameApi.ts"
	},
```

- [ ] **Step 3: Fix the reactivity warning in `overlay-controls.svelte`**

Open `.worktree/fix-build-warnings/immichFrame.Web/src/lib/components/elements/overlay-controls.svelte`. Find:

```ts
	// Define your shortcut list
	const shortcutList = [
		{
			key: 'ArrowRight',
			action: next
		},
		{
			key: 'ArrowLeft',
			action: back
		},
		{
			key: ' ',
			action: pause
		},
		{
			key: 'i',
			action: showInfo
		}
	];
```

Replace with (wraps the array in `$derived`, contents unchanged):

```ts
	// Define your shortcut list
	const shortcutList = $derived([
		{
			key: 'ArrowRight',
			action: next
		},
		{
			key: 'ArrowLeft',
			action: back
		},
		{
			key: ' ',
			action: pause
		},
		{
			key: 'i',
			action: showInfo
		}
	]);
```

- [ ] **Step 4: Fix the reactivity bug in `overlay-qr.svelte`**

Open `.worktree/fix-build-warnings/immichFrame.Web/src/lib/components/elements/imageoverlay/overlay-qr.svelte`. Find:

```ts
	let imageUrl = `https://my.immich.app/photos/${id}`;
```

Replace with:

```ts
	let imageUrl = $derived(`https://my.immich.app/photos/${id}`);
```

- [ ] **Step 5: Install dependencies (triggers the new `prepare` script) and run svelte-check**

```bash
cd C:\Users\johan\code\if-rahmen\.worktree\fix-build-warnings\immichFrame.Web
npm i
npm run check
```

Expected: `npm i` completes (the `prepare` script runs `svelte-kit sync` automatically as part of install — you should see it execute, not just `vite build`/`vite dev`). `npm run check` exits 0 with no errors. It's fine if pre-existing unrelated warnings remain (e.g. in `asset-info.svelte`, per this project's known state) — what matters is no `state_referenced_locally` warning for `overlay-controls.svelte` or `overlay-qr.svelte`, and no `Cannot find base config file` warning.

- [ ] **Step 6: Run the production build and confirm the warnings are gone**

```bash
npm run build
```

Expected: build succeeds. Confirm by inspecting the output that none of the following substrings appear: `Cannot find base config file`, `overlay-controls.svelte`, `overlay-qr.svelte`, `state_referenced_locally`.

- [ ] **Step 7: Commit**

```bash
cd C:\Users\johan\code\if-rahmen\.worktree\fix-build-warnings
git add immichFrame.Web/package.json immichFrame.Web/src/lib/components/elements/overlay-controls.svelte immichFrame.Web/src/lib/components/elements/imageoverlay/overlay-qr.svelte
git commit -m "fix: eliminate build warnings (svelte-kit sync prepare step, reactive shortcut list and QR/link URL)"
```

---

### Task 2: Live docker build + browser verification

**Files:** none (verification only — no code changes in this task).

**Interfaces:**
- Consumes: the `fix-build-warnings` branch committed in Task 1, checked out at `.worktree/fix-build-warnings`.
- Produces: a pass/fail verification report (in the task report file) covering the general smoke checks plus the QR-staleness-specific check. This is the last task before the human controller decides whether to push and open the PR — no code changes and no `git push`/PR creation happen here.

- [ ] **Step 1: Build the image directly (no docker-compose involvement)**

```bash
cd C:\Users\johan\code\if-rahmen\.worktree\fix-build-warnings
docker build -t immichframe-fix-test .
```

Expected: build succeeds (same multi-stage Dockerfile as the main build; this only differs from the existing `docker-compose.yml` build in that it points at the worktree instead of `ImmichFrame/`). Confirm again in this full build log that none of `Cannot find base config file`, `overlay-controls.svelte`, `overlay-qr.svelte`, `state_referenced_locally` appear.

- [ ] **Step 2: Run it on a scratch port, reusing the real Config-IF**

```bash
docker run --rm -d --name immichframe-fix-test -p 2285:8080 \
  -v "C:/Users/johan/code/if-rahmen/Config-IF:/app/Config" \
  -v "C:/Users/johan/code/if-rahmen/Config-IF/custom.css:/app/wwwroot/static/custom.css" \
  -e TZ=Europe/Berlin \
  immichframe-fix-test
```

Poll for readiness:

```bash
curl -sf -o /dev/null http://localhost:2285 && echo ready
```

Expected: `ready` within a few seconds (retry a couple of times with a short sleep if not immediate).

- [ ] **Step 3: General smoke checks via Playwright MCP tools**

Using the already-installed Playwright MCP tools directly (load their schemas via `ToolSearch` with query `select:mcp__plugin_playwright_playwright__browser_navigate,mcp__plugin_playwright_playwright__browser_snapshot,mcp__plugin_playwright_playwright__browser_console_messages,mcp__plugin_playwright_playwright__browser_network_requests,mcp__plugin_playwright_playwright__browser_click,mcp__plugin_playwright_playwright__browser_close` if not already loaded):

1. `browser_navigate` to `http://localhost:2285`.
2. `browser_snapshot` — confirm real content (not blank/error).
3. `browser_console_messages` (level `error`) — expect 0 entries.
4. `browser_network_requests` — expect no 4xx/5xx and nothing failed.

- [ ] **Step 4: QR-staleness-specific check (the real bug from `overlay-qr.svelte`)**

From the snapshot in Step 3, find the "Info" button's ref and click it:

```
browser_click with element="Info" button and its ref from the snapshot
```

Take a `browser_snapshot` and note the QR/link's target URL (the `href` on the "Open in immich" link, format `https://my.immich.app/photos/<id>`) and the asset id currently visible.

Close the info overlay (click "Info" again, or navigate away and back), wait `Interval + TransitionDuration + 5` seconds (read `Interval`/`TransitionDuration` from `Config-IF/Settings.yml`'s `General:` section, same as the `local-smoke-test` skill does) so the slideshow advances to a different asset, then reopen the info overlay and take another snapshot.

Expected (this is the actual regression test for the fix): the "Open in immich" link's asset id in the second snapshot is **different** from the first, and matches whatever asset is currently displayed — not frozen at the first-ever id. Before this fix, this URL would never change after the component's first render.

- [ ] **Step 5: Tear down**

```bash
docker stop immichframe-fix-test
docker rmi immichframe-fix-test
```

Expected: container stopped and removed, image removed. Confirm with `docker ps` (no `immichframe-fix-test` running) and `docker images` (no `immichframe-fix-test` image).

- [ ] **Step 6: Write the verification report**

Record in the task report file: the full Step 1 build log confirmation (warnings absent), Steps 3-4's actual observed values (console error count, network request count/status, the two QR/link URLs and asset ids before/after the wait, confirming they differ), and confirmation that teardown left no container/image behind. This is evidence for the human controller's push/PR decision — do not push or open a PR from this task.
