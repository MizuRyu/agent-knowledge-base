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

if [[ ! -f "$GBRAIN_DIR/src/cli.ts" ]]; then
  printf 'missing vendored gbrain runtime: %s\n' "$GBRAIN_DIR" >&2
  exit 1
fi

if [[ ! -d "$WORK_DIR" ]]; then
  printf 'missing work brain source: %s\n' "$WORK_DIR" >&2
  exit 1
fi

if ! git -C "$ROOT_DIR" rev-parse HEAD >/dev/null 2>&1; then
  printf 'missing Git commit: commit the repository before bootstrapping the work brain\n' >&2
  exit 1
fi

mkdir -p \
  "$WORK_DIR/.raw/projects" \
  "$WORK_DIR/.artifacts/projects" \
  "$WORK_DIR/.private" \
  "$WORK_DIR/_inbox" \
  "$WORK_DIR/projects" \
  "$WORK_DIR/people" \
  "$WORK_DIR/companies" \
  "$WORK_DIR/meetings" \
  "$WORK_DIR/decisions" \
  "$WORK_DIR/concepts" \
  "$WORK_DIR/source" \
  "$WORK_DIR/archive" \
  "$WORK_DIR/templates/documents/word" \
  "$WORK_DIR/templates/documents/powerpoint" \
  "$WORK_DIR/templates/documents/excel"

rm -rf "$GBRAIN_HOME/.gbrain"

"${GBRAIN[@]}" providers test --model ruri:ruri-v3-310m
"${GBRAIN[@]}" init --force --pglite --embedding-model ruri:ruri-v3-310m --embedding-dimensions 768
"${GBRAIN[@]}" schema use gbrain-recommended
"${GBRAIN[@]}" sources add work --path "$WORK_DIR"
"${GBRAIN[@]}" sync --source work --full --no-pull --no-embed
"${GBRAIN[@]}" extract links --source db --source-id work --include-frontmatter
"${GBRAIN[@]}" extract timeline --source db --source-id work
"${GBRAIN[@]}" embed --stale --source work
"${GBRAIN[@]}" storage status --repo "$WORK_DIR"
run_doctor

printf 'work brain bootstrap completed\n'
