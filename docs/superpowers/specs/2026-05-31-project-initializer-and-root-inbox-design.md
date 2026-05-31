# Project Initializer と Root Inbox の設計

作成日: 2026-05-31
状態: 承認済み

## 目的

新しい project の開始時に、MOC、分類フォルダ、meeting 雛形を一括生成できるようにする。

あわせて、user が未処理資料を投入する場所を `knowledge/work/_inbox/` 直下へ統合する。user は投入時点で project や資料種別を判断しない。coding agent が docs-processing 時に分類し、処理済み raw 原本だけを `.raw/projects/<project>/...` へ移動する。

## 決定

### Root Inbox

未処理 raw は work brain 全体で 1 つの root inbox に集約する。

```text
knowledge/work/
  _inbox/                       # user が未処理資料を雑に投入
  .raw/
    projects/<project>/...      # docs-processing 完了後の raw 原本
  projects/<project>/sources/   # 抽出・整理済み Markdown
```

`_inbox/.raw/` は廃止する。

理由:

- user に project 分類を要求しない。
- project が不明な資料も同じ入口で受け取れる。
- `_inbox/` を未処理、`.raw/` を処理済み raw アーカイブとして明確に分離できる。
- project ごとの inbox を作ると、投入時点で user が保存先を判断する必要がある。

`_inbox/README.md` と将来追加する `intake-log.md` は資料ではない。Agent が投入 raw を列挙する場合は、これらの管理ファイルを除外する。

### Project MOC

project の入口は `overview.md` とする。別の `MOC.md` は作らない。

`overview.md` は以下を持つ。

- project の現在の状態
- 未解決事項
- meeting、source、worklog、decision、concept への wikilink
- timeline

`overview.md` は MOC と project page を兼ねる。入口ページを分けないことで、更新箇所と semantic retrieval のノイズを増やさない。

### Project Scaffold

新規 project initializer は以下を一括生成する。

```text
knowledge/work/projects/<project-slug>/
  overview.md
  .templates/
    meeting.md.template
  meetings/
  sources/
    documents/
      01-要件定義/
      02-基本設計/
      03-詳細設計/
      04-チャットメッセージ/
      99-その他/
  decisions/
  concepts/
  worklog/
```

`overview.md` は `knowledge/work/templates/pages/project.md.template` を元に生成する。生成時に slug、表示名、作成日を反映する。

空 directory は Git で保持されないため、initializer は必要な directory に `.gitkeep` を置く。

`knowledge/work/projects/example-project/` は gbrain runtime の sample fixture であり、新規 project のコピー元にはしない。

### Meeting Template

新規 project には `.templates/meeting.md.template` を生成する。

`.templates/` は hidden directory であり、gbrain index の対象外とする。実在しない会議を通常 page として作らない。

meeting の保存先:

```text
projects/<project>/meetings/<meeting-slug>/yy/mm/
```

meeting のファイル名:

```text
yymmdd_hhmm_<title>.md
```

開始時間が不明な場合:

```text
yymmdd_<title>.md
```

例:

```text
projects/foo/meetings/weekly-sync/26/06/260601_1030_weekly-sync.md
projects/foo/meetings/design-review/26/06/260601_design-review.md
```

`.templates/meeting.md.template` は `knowledge/work/templates/pages/meeting.md.template` を元に生成し、project slug とファイル名規約を記載する。

### Initializer Interface

initializer は shell script として提供する。

```bash
scripts/knowledge/init-work-project.sh <project-slug> "<表示名>"
```

例:

```bash
scripts/knowledge/init-work-project.sh customer-portal "顧客ポータル"
```

入力規約:

- `<project-slug>` は英小文字、数字、`-` のみを許可する。
- 表示名は必須とする。
- 同名 project directory が存在する場合は上書きせず停止する。

生成後、user または coding agent は `overview.md` の現在の状態と未解決事項を更新する。

### Inbox Processing Flow

```text
user が knowledge/work/_inbox/ に資料を投入
  -> coding agent に docs-processing を依頼
  -> project と資料カテゴリを推定
  -> checksum と論理資料名で重複・版違いを判定
  -> extracted Markdown と overview.md の生成に成功
  -> raw 原本を .raw/projects/<project>/... へ移動
  -> projects/<project>/sources/... に加工済み Markdown を保存
  -> 判断不能または処理失敗時は _inbox/ に残す
```

raw 原本は docs-processing が成功するまで `_inbox/` から移動しない。失敗時に既存 raw と既存 processed Markdown を壊さない。

## 変更対象

- `scripts/knowledge/init-work-project.sh`
- `knowledge/work/_inbox/README.md`
- `knowledge/work/RESOLVER.md`
- `knowledge/work/templates/pages/project.md.template`
- `knowledge/work/templates/pages/meeting.md.template`
- `README.md`
- `docs/adr/0001-work-document-intake-and-gbrain-boundary.md`
- `docs/design/knowledge-vault-work.md`
- `docs/design/work-gbrain-architecture.md`
- `docs/memo/260531/01_work-brainの一日運用ライフサイクル.md`
- `scripts/knowledge/bootstrap-gbrain-work.sh`
- `scripts/knowledge/verify-gbrain-work.sh`

## 検証

- initializer が期待する tree を生成する。
- initializer が不正 slug、表示名なし、既存 project を拒否する。
- `_inbox/.raw/` が不要になる。
- `_inbox/`、`.raw/projects/`、`.templates/meeting.md.template` の役割が README と設計資料で一致する。
- `.templates/meeting.md.template` が gbrain index に混入しない。
- 既存の bootstrap と verify が通る。
