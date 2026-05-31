#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GBRAIN_DIR="$ROOT_DIR/gbrain"
WORK_DIR="$ROOT_DIR/knowledge/work"
export GBRAIN_HOME="${GBRAIN_HOME:-$ROOT_DIR/.gbrain-work}"
export UV_CACHE_DIR="${UV_CACHE_DIR:-$ROOT_DIR/.uv-cache}"

GBRAIN=(env -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u ZEROENTROPY_API_KEY -u VOYAGE_API_KEY -u OPENROUTER_API_KEY -u GOOGLE_GENERATIVE_AI_API_KEY bun run "$GBRAIN_DIR/src/cli.ts")

private_sentinel="$WORK_DIR/.private/__verify-private-sentinel.md"
cleanup() {
  rm -f "$private_sentinel"
}
trap cleanup EXIT

required_files=(
  "$ROOT_DIR/.gitignore"
  "$ROOT_DIR/scripts/knowledge/init-work-project.sh"
  "$ROOT_DIR/scripts/knowledge/test-init-work-project.sh"
  "$ROOT_DIR/scripts/knowledge/maintain-gbrain-work.sh"
  "$WORK_DIR/gbrain.yml"
  "$WORK_DIR/.gitignore"
  "$WORK_DIR/RESOLVER.md"
  "$WORK_DIR/schema.md"
  "$WORK_DIR/ACCESS_POLICY.md"
  "$WORK_DIR/index.md"
  "$WORK_DIR/projects/example-project/overview.md"
  "$WORK_DIR/projects/example-project/.templates/meeting.md.template"
  "$WORK_DIR/projects/example-project/meetings/sample-meeting/yy/mm/yymmdd_hhmm_sample-meeting.md"
  "$WORK_DIR/projects/example-project/worklog/yy/mm/yymmdd/nn-sample-task.md"
  "$WORK_DIR/projects/example-project/sources/documents/01-要件定義/sample-source/overview.md"
  "$WORK_DIR/projects/example-project/sources/documents/01-要件定義/sample-source/extracted/sample-file/00-概要.md"
  "$WORK_DIR/projects/example-project/sources/documents/01-要件定義/sample-source/views/sample-file/260601_summary.md"
  "$WORK_DIR/concepts/document-intake-pipeline.md"
)

for file in "${required_files[@]}"; do
  test -f "$file" || { printf 'missing file: %s\n' "$file" >&2; exit 1; }
done

git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null
git -C "$ROOT_DIR" rev-parse HEAD >/dev/null
test ! -e "$ROOT_DIR/tmp" || { printf 'obsolete tmp directory remains\n' >&2; exit 1; }
test ! -e "$GBRAIN_DIR/.git" || { printf 'nested gbrain git metadata remains\n' >&2; exit 1; }

required_dirs=(
  "$WORK_DIR/.raw/projects"
  "$WORK_DIR/.artifacts/projects"
  "$WORK_DIR/.private"
  "$WORK_DIR/_inbox"
  "$WORK_DIR/projects"
  "$WORK_DIR/people"
  "$WORK_DIR/companies"
  "$WORK_DIR/concepts"
  "$WORK_DIR/source"
)

for dir in "${required_dirs[@]}"; do
  test -d "$dir" || { printf 'missing dir: %s\n' "$dir" >&2; exit 1; }
done

test ! -e "$WORK_DIR/_inbox/.raw" || {
  printf 'deprecated inbox directory remains: %s\n' "$WORK_DIR/_inbox/.raw" >&2
  exit 1
}

if rg -n '_raw|raw-store|versions/|task_shadow|task-shadow|manifest\.md|\.support|\bOrganization\b|example-project/index|sample-source/index' "$WORK_DIR"; then
  printf 'deprecated vocabulary found\n' >&2
  exit 1
fi

rg -n '<!-- timeline -->' "$WORK_DIR/projects" "$WORK_DIR/concepts" >/dev/null
rg -n '^- \*\*[0-9]{4}-[0-9]{2}-[0-9]{2}\*\* \| .+ — .+' "$WORK_DIR/projects" "$WORK_DIR/concepts" >/dev/null
rg -n '\[\[projects/example-project|\[\[concepts/document-intake-pipeline|raw://work/|artifact://work/' "$WORK_DIR" >/dev/null

"$ROOT_DIR/scripts/knowledge/test-init-work-project.sh" >/tmp/gbrain-work-init-project.txt

printf '# identity-map sentinel\n\nidentity-map should not be indexed.\n' >"$private_sentinel"

"${GBRAIN[@]}" providers list | rg -n '^ruri\s+native\s+yes' >/dev/null
"${GBRAIN[@]}" storage status --repo "$WORK_DIR" --json >/tmp/gbrain-work-storage.json
jq -e '.config.db_tracked | index("projects/")' /tmp/gbrain-work-storage.json >/dev/null
"${GBRAIN[@]}" extract links --source db --source-id work --include-frontmatter >/tmp/gbrain-work-extract-links.txt
"${GBRAIN[@]}" extract timeline --source db --source-id work >/tmp/gbrain-work-extract-timeline.txt

"${GBRAIN[@]}" search "サンプルプロジェクト" >/tmp/gbrain-work-search-project.txt
rg -n 'example-project|サンプルプロジェクト' /tmp/gbrain-work-search-project.txt >/dev/null

"${GBRAIN[@]}" search "資料取り込みパイプライン" >/tmp/gbrain-work-search-concept.txt
rg -n 'document-intake-pipeline|資料取り込みパイプライン' /tmp/gbrain-work-search-concept.txt >/dev/null

"${GBRAIN[@]}" query "仕事用の raw 資料はどのように扱うべきですか？" --no-expand >/tmp/gbrain-work-query.txt
rg -n '資料取り込みパイプライン|サンプル資料|raw 原本|処理済み Markdown' /tmp/gbrain-work-query.txt >/dev/null

"${GBRAIN[@]}" graph projects/example-project/overview --depth 2 >/tmp/gbrain-work-graph.txt
rg -n 'concepts/document-intake-pipeline|projects/example-project/worklog|projects/example-project/meetings' /tmp/gbrain-work-graph.txt >/dev/null

if "${GBRAIN[@]}" search "identity-map" | rg -n 'identity-map'; then
  printf 'private sidecar content appears indexed\n' >&2
  exit 1
fi

"${GBRAIN[@]}" stats >/tmp/gbrain-work-stats.txt
rg -n '^Timeline:[[:space:]]+[1-9][0-9]*$' /tmp/gbrain-work-stats.txt >/dev/null

printf 'gbrain work verification passed\n'
