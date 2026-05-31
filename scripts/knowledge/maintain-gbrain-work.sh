#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GBRAIN_DIR="$ROOT_DIR/gbrain"
WORK_DIR="$ROOT_DIR/knowledge/work"
export GBRAIN_HOME="${GBRAIN_HOME:-$ROOT_DIR/.gbrain-work}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$ROOT_DIR/.uv-cache}"

GBRAIN=(env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u ZEROENTROPY_API_KEY -u VOYAGE_API_KEY -u OPENROUTER_API_KEY -u GOOGLE_GENERATIVE_AI_API_KEY bun run "$GBRAIN_DIR/src/cli.ts")

run_doctor() {
  if ! "${GBRAIN[@]}" doctor --json; then
    printf 'gbrain doctor reported warnings or failures; inspect the JSON above\n' >&2
  fi
}

if ! git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
  printf 'missing Git commit: commit Markdown changes before running maintenance\n' >&2
  exit 1
fi

if ! git -C "$ROOT_DIR" diff --quiet -- knowledge/work ||
   ! git -C "$ROOT_DIR" diff --cached --quiet -- knowledge/work; then
  printf 'uncommitted work brain changes: commit Markdown changes before running maintenance\n' >&2
  exit 1
fi

"${GBRAIN[@]}" sync --source work --no-pull --no-embed
"${GBRAIN[@]}" extract links --source db --source-id work --include-frontmatter
"${GBRAIN[@]}" extract timeline --source db --source-id work
"${GBRAIN[@]}" embed --stale --source work
run_doctor

printf 'work brain maintenance completed\n'
