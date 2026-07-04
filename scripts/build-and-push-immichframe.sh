#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <source-dir> [image]" >&2
  exit 2
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
fi

SOURCE_INPUT="$1"
IMAGE_NAME="${2:-jayar79/immichframe:test}"

# Normalize source path against workspace
if [[ "${SOURCE_INPUT}" = /* ]]; then
  ABS_SOURCE="$(realpath -m -- "${SOURCE_INPUT}")"
else
  ABS_SOURCE="$(realpath -m -- "${WORKSPACE_ROOT}/${SOURCE_INPUT}")"
fi

# Ensure source exists
if [ ! -d "${ABS_SOURCE}" ]; then
  echo "Source directory does not exist: ${SOURCE_INPUT}" >&2
  exit 2
fi

# Ensure source is inside workspace
case "${ABS_SOURCE}" in
  "${WORKSPACE_ROOT}/ImmichFrame"|"${WORKSPACE_ROOT}/.worktree"/*)
    ;; # allowed
  *)
    echo "Unsupported source: ${SOURCE_INPUT}" >&2
    exit 2
    ;;
esac

# Ensure Dockerfile exists at root of source
if [ ! -f "${ABS_SOURCE}/Dockerfile" ]; then
  echo "Source directory does not contain a Dockerfile: ${ABS_SOURCE}" >&2
  exit 2
fi

# Ensure docker CLI available
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but was not found in PATH" >&2
  exit 2
fi

# Print info and run docker build/push
echo "Source: ${ABS_SOURCE}"
echo "Image: ${IMAGE_NAME}"

docker build -t "${IMAGE_NAME}" "${ABS_SOURCE}"
docker push "${IMAGE_NAME}"
