#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/knowledge/work}"

usage() {
  printf 'usage: %s <project-slug> "<display-name>"\n' "$0" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

project_slug="$1"
display_name="$2"

if [[ ! "$project_slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  printf 'invalid project slug: use lowercase letters, digits, and single hyphens\n' >&2
  exit 1
fi

if [[ -z "$display_name" ]]; then
  printf 'display name must not be empty\n' >&2
  exit 1
fi

project_dir="$WORK_DIR/projects/$project_slug"
if [[ -e "$project_dir" ]]; then
  printf 'project already exists: %s\n' "$project_dir" >&2
  exit 1
fi

mkdir -p \
  "$project_dir/.templates" \
  "$project_dir/meetings" \
  "$project_dir/sources/documents/01-要件定義" \
  "$project_dir/sources/documents/02-基本設計" \
  "$project_dir/sources/documents/03-詳細設計" \
  "$project_dir/sources/documents/04-チャットメッセージ" \
  "$project_dir/sources/documents/99-その他" \
  "$project_dir/decisions" \
  "$project_dir/concepts" \
  "$project_dir/worklog"

cp "$WORK_DIR/templates/pages/project.md.template" "$project_dir/overview.md"
sed -i.bak "s/^# プロジェクトタイトル$/# $display_name/" "$project_dir/overview.md"
rm "$project_dir/overview.md.bak"

cp "$WORK_DIR/templates/pages/meeting.md.template" "$project_dir/.templates/meeting.md.template"
sed -i.bak "s/^project: project-slug$/project: $project_slug/" "$project_dir/.templates/meeting.md.template"
rm "$project_dir/.templates/meeting.md.template.bak"
cat >>"$project_dir/.templates/meeting.md.template" <<'EOF'

## ファイル名規約

- 開始時間が分かる場合: `yymmdd_hhmm_<title>.md`
- 開始時間が不明な場合: `yymmdd_<title>.md`
EOF

touch \
  "$project_dir/meetings/.gitkeep" \
  "$project_dir/sources/documents/01-要件定義/.gitkeep" \
  "$project_dir/sources/documents/02-基本設計/.gitkeep" \
  "$project_dir/sources/documents/03-詳細設計/.gitkeep" \
  "$project_dir/sources/documents/04-チャットメッセージ/.gitkeep" \
  "$project_dir/sources/documents/99-その他/.gitkeep" \
  "$project_dir/decisions/.gitkeep" \
  "$project_dir/concepts/.gitkeep" \
  "$project_dir/worklog/.gitkeep"

printf 'created work project: %s\n' "$project_dir"
