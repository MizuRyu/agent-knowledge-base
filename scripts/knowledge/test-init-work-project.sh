#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/knowledge/init-work-project.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

WORK_DIR="$TMP_DIR/knowledge/work"
mkdir -p "$WORK_DIR/templates/pages"
cp "$ROOT_DIR/knowledge/work/templates/pages/project.md.template" "$WORK_DIR/templates/pages/project.md.template"
cp "$ROOT_DIR/knowledge/work/templates/pages/meeting.md.template" "$WORK_DIR/templates/pages/meeting.md.template"

WORK_DIR="$WORK_DIR" "$SCRIPT" customer-portal "顧客ポータル"

PROJECT_DIR="$WORK_DIR/projects/customer-portal"
test -f "$PROJECT_DIR/overview.md"
test -f "$PROJECT_DIR/.templates/meeting.md.template"
test -f "$PROJECT_DIR/meetings/.gitkeep"
test -f "$PROJECT_DIR/sources/documents/01-要件定義/.gitkeep"
test -f "$PROJECT_DIR/sources/documents/02-基本設計/.gitkeep"
test -f "$PROJECT_DIR/sources/documents/03-詳細設計/.gitkeep"
test -f "$PROJECT_DIR/sources/documents/04-チャットメッセージ/.gitkeep"
test -f "$PROJECT_DIR/sources/documents/99-その他/.gitkeep"
test -f "$PROJECT_DIR/decisions/.gitkeep"
test -f "$PROJECT_DIR/concepts/.gitkeep"
test -f "$PROJECT_DIR/worklog/.gitkeep"

rg -n '^# 顧客ポータル$' "$PROJECT_DIR/overview.md" >/dev/null
rg -n '^repos: \[\]$' "$PROJECT_DIR/overview.md" >/dev/null
rg -n '^worklog_root: worklog$' "$PROJECT_DIR/overview.md" >/dev/null
rg -n '^project: customer-portal$' "$PROJECT_DIR/.templates/meeting.md.template" >/dev/null
rg -n 'yymmdd_hhmm_<title>\.md' "$PROJECT_DIR/.templates/meeting.md.template" >/dev/null
rg -n 'yymmdd_<title>\.md' "$PROJECT_DIR/.templates/meeting.md.template" >/dev/null

if WORK_DIR="$WORK_DIR" "$SCRIPT" customer-portal "重複" >/dev/null 2>&1; then
  printf 'initializer accepted an existing project\n' >&2
  exit 1
fi

if WORK_DIR="$WORK_DIR" "$SCRIPT" Customer_Portal "不正 slug" >/dev/null 2>&1; then
  printf 'initializer accepted an invalid slug\n' >&2
  exit 1
fi

if WORK_DIR="$WORK_DIR" "$SCRIPT" missing-title >/dev/null 2>&1; then
  printf 'initializer accepted a missing display name\n' >&2
  exit 1
fi

printf 'work project initializer verification passed\n'
