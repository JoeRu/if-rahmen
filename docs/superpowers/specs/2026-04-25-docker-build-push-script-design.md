# Docker build/push helper script design

## Problem

The workspace needs a small helper script in `scripts/` that can build and push a Docker image from one explicitly chosen checkout directory. The supported sources are the local `ImmichFrame/` clone and worktree checkouts under `.worktree/`. The default image tag should be `jayar79/immichframe:test`.

## Proposed approach

Add a Bash script in `scripts/` that:

- requires a source checkout argument instead of silently choosing a default
- accepts an optional image argument and defaults it to `jayar79/immichframe:test`
- resolves the source relative to the workspace root derived from the script location
- validates that the source is one of the allowed workspace checkouts
- validates that the selected checkout contains the root `Dockerfile`
- runs a normal single-architecture `docker build` followed by `docker push`

This keeps the helper aligned with the repository's existing root-level Docker build surface while avoiding CI-only complexity such as multi-platform Buildx publishing.

## CLI design

### Command shape

```bash
scripts/build-and-push-immichframe.sh <source-dir> [image]
```

### Arguments

- `source-dir` (required): path to a supported checkout, relative to the workspace root or absolute
- `image` (optional): Docker image reference to tag and push; defaults to `jayar79/immichframe:test`

### Supported sources

The script should accept source directories that resolve to:

- `ImmichFrame`
- `.worktree/main-replay`
- `.worktree/personal-main`
- other `.worktree/<name>` directories, as long as they remain inside the workspace and contain the root `Dockerfile`

## Behavior

1. Determine the workspace root from the script's own path.
2. Read the required source argument and optional image argument.
3. Resolve the source to an absolute path.
4. Reject sources outside the workspace root.
5. Reject sources that are not `ImmichFrame` or children of `.worktree/`.
6. Reject sources that do not contain the root-level `Dockerfile`.
7. Print the resolved source path and target image tag.
8. Run `docker build -t <image> <source>`.
9. Run `docker push <image>`.

## Error handling

- Missing source argument: print usage and exit non-zero.
- Invalid source path: print a clear error and exit non-zero.
- Source outside workspace or unsupported directory: print a clear error and exit non-zero.
- Missing `Dockerfile`: print a clear error and exit non-zero.
- Missing Docker CLI: print a clear error and exit non-zero.
- Docker build or push failure: allow the Docker command to fail visibly and propagate its exit code.

The script should not attempt to run `docker login` or manage registry credentials automatically.

## Compatibility and maintenance

- Implement in Bash to match the existing `scripts/` helpers.
- Keep the script dependency-free beyond Docker and standard shell utilities.
- Use the checkout root as the Docker build context so it stays aligned with the existing root `Dockerfile`.
- Include a short usage string at the top of the script for discoverability.

## Testing considerations

- Validate that the script rejects missing and invalid source arguments before invoking Docker.
- Validate that the script accepts a valid checkout and the default image tag.
- Validate that overriding the image tag works.
- Validate that the script uses the selected checkout root as the build context.
