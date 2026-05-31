# Project Initializer and Root Inbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新規 work project の MOC と標準 directory を一括生成し、未処理 raw の入口を root `_inbox/` に統合する。

**Architecture:** `scripts/knowledge/init-work-project.sh` を project scaffold の唯一の入口とする。user の未分類投入先は `knowledge/work/_inbox/` 直下、処理後の raw アーカイブは `.raw/projects/` とし、既存の `_inbox/.raw/` を廃止する。project の `overview.md` は MOC を兼ね、project-local `.templates/meeting.md.template` は hidden directory 配下に置いて gbrain index への混入を防ぐ。

**Tech Stack:** Bash, Markdown, Git, vendored gbrain CLI, local PGLite, local ruri-v3 embedding

---

## File Structure

### Create

- `scripts/knowledge/init-work-project.sh`
  - slug と表示名を受け取り、project scaffold を生成する。
- `scripts/knowledge/test-init-work-project.sh`
  - temp directory を使い、initializer の正常系と異常系を検証する。

### Modify

- `README.md`
  - root inbox と initializer の利用方法を記載する。
- `knowledge/work/_inbox/README.md`
  - 未処理資料を `_inbox/` 直下に置く規約へ変更する。
- `.gitignore`
  - root inbox の資料ファイルを除外し、管理ファイルだけを追跡する。
- `knowledge/work/.gitignore`
  - work brain 単体でも root inbox の資料ファイルを除外する。
- `knowledge/work/RESOLVER.md`
  - 未処理 raw の保存先を `_inbox/` へ変更する。
- `scripts/knowledge/bootstrap-gbrain-work.sh`
  - `_inbox/.raw/` の作成を廃止し、`_inbox/` だけを作成する。
- `scripts/knowledge/verify-gbrain-work.sh`
  - `_inbox/.raw/` が存在しないこと、initializer test が通ること、`.templates/meeting.md.template` が index されないことを確認する。
- `docs/adr/0001-work-document-intake-and-gbrain-boundary.md`
  - root inbox と処理後 raw 移動の境界を更新する。
- `docs/design/knowledge-vault-work.md`
  - directory tree、責務、routing flow を更新する。
- `docs/design/work-gbrain-architecture.md`
  - docs-processing lifecycle を root inbox に合わせる。
- `docs/memo/260531/01_work-brainの一日運用ライフサイクル.md`
  - 日常運用と scheduled 候補の表記を更新する。
- `docs/superpowers/specs/2026-05-31-document-intake-dedup-design.md`
  - dedup 処理の入出力パスを root inbox に合わせる。

## Task 1: Add a Failing Initializer Test

**Files:**
- Create: `scripts/knowledge/test-init-work-project.sh`

- [ ] **Step 1: Add the shell fixture test**

```bash
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
rg -n '^project: customer-portal$' "$PROJECT_DIR/.templates/meeting.md.template" >/dev/null
rg -n 'yymmdd_hhmm_<title>\\.md' "$PROJECT_DIR/.templates/meeting.md.template" >/dev/null
rg -n 'yymmdd_<title>\\.md' "$PROJECT_DIR/.templates/meeting.md.template" >/dev/null

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
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x scripts/knowledge/test-init-work-project.sh
```

- [ ] **Step 3: Run the test to verify it fails**

Run:

```bash
scripts/knowledge/test-init-work-project.sh
```

Expected: FAIL because `scripts/knowledge/init-work-project.sh` does not exist.

## Task 2: Implement the Project Initializer

**Files:**
- Create: `scripts/knowledge/init-work-project.sh`

- [ ] **Step 1: Add the initializer**

```bash
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
```

- [ ] **Step 2: Make the initializer executable**

Run:

```bash
chmod +x scripts/knowledge/init-work-project.sh
```

- [ ] **Step 3: Run the fixture test**

Run:

```bash
scripts/knowledge/test-init-work-project.sh
```

Expected:

```text
work project initializer verification passed
```

## Task 3: Replace `_inbox/.raw/` with Root `_inbox/`

**Files:**
- Modify: `.gitignore`
- Modify: `knowledge/work/.gitignore`
- Modify: `knowledge/work/_inbox/README.md`
- Modify: `knowledge/work/RESOLVER.md`
- Modify: `scripts/knowledge/bootstrap-gbrain-work.sh`
- Modify: `scripts/knowledge/verify-gbrain-work.sh`

- [ ] **Step 1: Update the human and Agent rules**

Use `_inbox/` as the only incoming raw path:

```md
# Work Inbox

user から受領した未処理ファイルは `_inbox/` 直下に置く。

`_inbox/` の資料ファイルは knowledge page ではない。プロジェクト資料として受け入れる場合は、docs-processing に成功した後で `.raw/projects/<project>/...` 配下へ移動する。処理後は論理資料名ごとに整理し、受領時のファイル名を維持した最新版 raw だけを残す。
```

Change the resolver entry to:

```md
2. user から受領した未処理 raw ファイル -> `_inbox/`
```

- [ ] **Step 2: Ignore incoming files while retaining management files**

Use these ignore rules:

```gitignore
knowledge/work/_inbox/*
!knowledge/work/_inbox/README.md
!knowledge/work/_inbox/intake-log.md
```

Use the equivalent work-local rules in `knowledge/work/.gitignore`:

```gitignore
_inbox/*
!_inbox/README.md
!_inbox/intake-log.md
```

- [ ] **Step 3: Update bootstrap directory creation**

Replace:

```bash
"$WORK_DIR/_inbox/.raw" \
```

with:

```bash
"$WORK_DIR/_inbox" \
```

- [ ] **Step 4: Update runtime verification**

Require `_inbox/`, reject `_inbox/.raw/`, and invoke the initializer fixture test:

```bash
required_dirs=(
  "$WORK_DIR/.raw/projects"
  "$WORK_DIR/.artifacts/projects"
  "$WORK_DIR/.private"
  "$WORK_DIR/_inbox"
  ...
)

test ! -e "$WORK_DIR/_inbox/.raw" || {
  printf 'deprecated inbox directory remains: %s\n' "$WORK_DIR/_inbox/.raw" >&2
  exit 1
}

"$ROOT_DIR/scripts/knowledge/test-init-work-project.sh"
```

- [ ] **Step 5: Remove the obsolete empty directory**

Run:

```bash
rmdir knowledge/work/_inbox/.raw
```

Expected: exit 0.

## Task 4: Update README and Design Documents

**Files:**
- Modify: `README.md`
- Modify: `docs/adr/0001-work-document-intake-and-gbrain-boundary.md`
- Modify: `docs/design/knowledge-vault-work.md`
- Modify: `docs/design/work-gbrain-architecture.md`
- Modify: `docs/memo/260531/01_work-brainの一日運用ライフサイクル.md`
- Modify: `docs/superpowers/specs/2026-05-31-document-intake-dedup-design.md`

- [ ] **Step 1: Replace incoming paths**

Run:

```bash
rg -n '_inbox/\\.raw|_inbox\\.raw' README.md knowledge docs scripts
```

For each active design and guide file listed above, replace `_inbox/.raw/` and `_inbox/.raw` with `_inbox/`.

- [ ] **Step 2: Document the root inbox lifecycle**

Ensure each guide states:

```text
_inbox/                       # user が雑に置く未処理 raw
.raw/projects/<project>/...   # docs-processing 成功後の raw 原本
projects/<project>/sources/   # 抽出・整理済み Markdown
```

- [ ] **Step 3: Document the initializer**

Add this command to `README.md`:

```bash
scripts/knowledge/init-work-project.sh customer-portal "顧客ポータル"
```

Document the generated tree and explain that `overview.md` is the MOC. Explain that `.templates/meeting.md.template` is index-excluded and that actual meeting pages use:

```text
meetings/<meeting-slug>/yy/mm/yymmdd_hhmm_<title>.md
meetings/<meeting-slug>/yy/mm/yymmdd_<title>.md
```

## Task 5: Verify the Complete Lifecycle

**Files:**
- Verify: `README.md`
- Verify: `knowledge/work/`
- Verify: `scripts/knowledge/`

- [ ] **Step 1: Check shell syntax and diffs**

Run:

```bash
bash -n scripts/knowledge/*.sh
git diff --check -- README.md knowledge docs scripts
```

Expected: exit 0.

- [ ] **Step 2: Run the initializer fixture**

Run:

```bash
scripts/knowledge/test-init-work-project.sh
```

Expected:

```text
work project initializer verification passed
```

- [ ] **Step 3: Check deprecated inbox references**

Run:

```bash
rg -n '_inbox/\\.raw|_inbox\\.raw' README.md knowledge docs scripts
```

Expected: no matches outside historical implementation plans.

- [ ] **Step 4: Rebuild the derived work brain**

Run:

```bash
scripts/knowledge/bootstrap-gbrain-work.sh
```

Expected: output includes:

```text
work brain bootstrap completed
```

- [ ] **Step 5: Run work brain verification**

Run:

```bash
scripts/knowledge/verify-gbrain-work.sh
```

Expected:

```text
gbrain work verification passed
```
