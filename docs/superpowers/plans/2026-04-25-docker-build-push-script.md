# Docker Build/Push Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Bash helper in `scripts/` that builds and pushes a Docker image from an explicitly chosen `ImmichFrame` checkout or `.worktree/<name>` checkout, defaulting the image tag to `jayar79/immichframe:test`.

**Architecture:** Keep the implementation in one focused Bash script under `scripts/`. The script should derive the workspace root from its own location, validate that the requested source stays inside the workspace and points at either `ImmichFrame/` or a child of `.worktree/`, then run a standard single-architecture `docker build` followed by `docker push`.

**Tech Stack:** Bash, Docker CLI

---

**Git note:** The workspace root is not a git repository, so this plan intentionally omits commit steps.

## File structure

- Create: `scripts/build-and-push-immichframe.sh` — standalone helper script with argument parsing, path validation, usage output, and Docker build/push execution.
- No dedicated test file — validate behavior with explicit shell commands and a stub `docker` executable in a temporary directory so the script can be exercised without a real image build during development.

### Task 1: Create the script skeleton and argument handling

**Files:**
- Create: `scripts/build-and-push-immichframe.sh`
- Test: inline shell commands from `/mnt/c/Users/johan/code/if-rahmen`

- [ ] **Step 1: Write the failing argument-handling check**

```bash
bash scripts/build-and-push-immichframe.sh
```

Expected: non-zero exit with a usage message. Before implementation this should fail because the file does not exist yet.

- [ ] **Step 2: Run the failing check**

Run:

```bash
bash scripts/build-and-push-immichframe.sh
```

Expected: FAIL with `No such file or directory` or equivalent missing-file error.

- [ ] **Step 3: Write the initial script with usage, workspace-root resolution, and default image handling**

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <source-dir> [image]" >&2
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 1
fi

SOURCE_INPUT="$1"
IMAGE_NAME="${2:-jayar79/immichframe:test}"
```

Then append executable permission after writing:

```bash
chmod +x scripts/build-and-push-immichframe.sh
```

- [ ] **Step 4: Run the argument-handling check again**

Run:

```bash
bash scripts/build-and-push-immichframe.sh
```

Expected: non-zero exit with exactly the usage line from the script, not a missing-file error.

### Task 2: Add source-path validation and Docker command execution

**Files:**
- Modify: `scripts/build-and-push-immichframe.sh`
- Test: inline shell commands from `/mnt/c/Users/johan/code/if-rahmen`

- [ ] **Step 1: Write the failing invalid-source check**

```bash
bash scripts/build-and-push-immichframe.sh not-a-checkout
```

Expected: non-zero exit with a clear message that the source path is invalid or unsupported.

- [ ] **Step 2: Run the invalid-source check to verify current behavior is incomplete**

Run:

```bash
bash scripts/build-and-push-immichframe.sh not-a-checkout
```

Expected: FAIL because the script does not yet resolve and validate source paths.

- [ ] **Step 3: Extend the script to normalize paths, allow only `ImmichFrame` or `.worktree/<name>`, verify `Dockerfile`, and invoke Docker**

```bash
if [[ "${SOURCE_INPUT}" = /* ]]; then
  ABS_SOURCE="$(realpath -m -- "${SOURCE_INPUT}")"
else
  ABS_SOURCE="$(realpath -m -- "${WORKSPACE_ROOT}/${SOURCE_INPUT}")"
fi

if [[ ! -d "${ABS_SOURCE}" ]]; then
  echo "Source directory does not exist: ${SOURCE_INPUT}" >&2
  exit 1
fi

case "${ABS_SOURCE}" in
  "${WORKSPACE_ROOT}/ImmichFrame"|"${WORKSPACE_ROOT}/.worktree/"*)
    ;;
  *)
    echo "Source must be ImmichFrame or a .worktree child: ${SOURCE_INPUT}" >&2
    exit 1
    ;;
esac

if [[ ! -f "${ABS_SOURCE}/Dockerfile" ]]; then
  echo "No Dockerfile found in source directory: ${ABS_SOURCE}" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but was not found in PATH" >&2
  exit 1
fi

echo "Source: ${ABS_SOURCE}"
echo "Image: ${IMAGE_NAME}"

docker build -t "${IMAGE_NAME}" "${ABS_SOURCE}"
docker push "${IMAGE_NAME}"
```

Keep the earlier usage and default-image code in place above this block.

- [ ] **Step 4: Run the invalid-source check again**

Run:

```bash
bash scripts/build-and-push-immichframe.sh not-a-checkout
```

Expected: non-zero exit with `Source directory does not exist: not-a-checkout`.

### Task 3: Smoke-test valid execution with a stub Docker binary

**Files:**
- Modify: `scripts/build-and-push-immichframe.sh` only if the smoke test exposes quoting or path-handling issues
- Test: inline shell commands from `/mnt/c/Users/johan/code/if-rahmen`

- [ ] **Step 1: Write the smoke-test command for the default image**

```bash
tmpdir="$(mktemp -d)" && \
cat >"${tmpdir}/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*"
EOF
chmod +x "${tmpdir}/docker" && \
PATH="${tmpdir}:$PATH" bash scripts/build-and-push-immichframe.sh ImmichFrame
```

Expected: the script prints the resolved source and `Image: jayar79/immichframe:test`, then the stub prints `docker build -t jayar79/immichframe:test ...` and `docker push jayar79/immichframe:test`.

- [ ] **Step 2: Run the default-image smoke test**

Run:

```bash
tmpdir="$(mktemp -d)" && \
cat >"${tmpdir}/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*"
EOF
chmod +x "${tmpdir}/docker" && \
PATH="${tmpdir}:$PATH" bash scripts/build-and-push-immichframe.sh ImmichFrame
```

Expected: PASS with stubbed `docker build` and `docker push` lines, no real Docker build.

- [ ] **Step 3: Write the smoke-test command for an overridden image**

```bash
tmpdir="$(mktemp -d)" && \
cat >"${tmpdir}/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*"
EOF
chmod +x "${tmpdir}/docker" && \
PATH="${tmpdir}:$PATH" bash scripts/build-and-push-immichframe.sh .worktree/main-replay custom/example:dev
```

Expected: the script prints `Image: custom/example:dev`, then the stub prints `docker build -t custom/example:dev ...` and `docker push custom/example:dev`.

- [ ] **Step 4: Run the override-image smoke test**

Run:

```bash
tmpdir="$(mktemp -d)" && \
cat >"${tmpdir}/docker" <<'EOF'
#!/usr/bin/env bash
printf 'docker %s\n' "$*"
EOF
chmod +x "${tmpdir}/docker" && \
PATH="${tmpdir}:$PATH" bash scripts/build-and-push-immichframe.sh .worktree/main-replay custom/example:dev
```

Expected: PASS with the overridden image name flowing through both Docker commands.
