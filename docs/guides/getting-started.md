# agent-knowledge-base 初回導入ガイド

このガイドは、`agent-knowledge-base` を初めて導入する user と coding agent のための onboarding checklist です。

上から順に実行すると、work brain の初回構築、動作確認、最初の project 作成、外部 repository からの参照、最初の資料投入まで完了します。

## 1. Repository を確認する

repository root へ移動します。

```bash
cd /path/to/agent-knowledge-base
```

必要な CLI を確認します。

```bash
git --version
bun --version
uv --version
```

前提:

- Git が利用できる。
- Bun が利用できる。
- `uv` が利用できる。
- 初回 bootstrap 時に local embedding model `cl-nagoya/ruri-v3-310m` を取得できる。
- Python package と model の初回取得時だけ、外部 network access が必要になる場合がある。
- knowledge の内容を外部 LLM に送信しない。

vendored gbrain の JavaScript dependency が未導入の場合だけ、以下を実行します。

```bash
cd gbrain
bun install
cd ..
```

## 2. 初回 Commit を作る

work brain の Markdown は Git を system of record として扱います。bootstrap の前に、repository に 1 件以上の commit が必要です。

```bash
git status
git add .
git commit -m "chore: initialize agent knowledge base"
```

既に commit が存在する場合は、新しい commit を作る必要はありません。

```bash
git rev-parse --short HEAD
```

commit hash が表示されれば次へ進めます。

## 3. Work Brain を Bootstrap する

初回構築スクリプトを実行します。

```bash
scripts/knowledge/bootstrap-gbrain-work.sh
```

内部では以下を実行します。

```text
local ruri-v3 provider の probe
  -> PGLite DB の作成
  -> gbrain-recommended schema の適用
  -> knowledge/work の source 登録
  -> Markdown の full sync
  -> wikilink edge の抽出
  -> timeline の抽出
  -> stale chunk の embedding
  -> doctor
```

完了時に以下が表示されます。

```text
work brain bootstrap completed
```

`bootstrap-gbrain-work.sh` は derived DB を削除して再構築します。日常運用では実行しません。

### Doctor の既知警告

初期状態では `doctor` が `cycle_freshness` を fail と表示する場合があります。

これは upstream gbrain の `dream` / `autopilot` cycle をまだ有効化していないためです。work brain v1 は明示的な maintenance を採用しているため、この警告だけで導入失敗とは判断しません。

## 4. 初期状態を Verify する

構成、検索、graph、semantic retrieval、index 除外ルールを確認します。

```bash
scripts/knowledge/verify-gbrain-work.sh
```

完了時に以下が表示されます。

```text
gbrain work verification passed
```

verify は以下も確認します。

- local `ruri-v3-310m` provider が利用できる。
- PoC project を keyword search と semantic query で取得できる。
- wikilink から graph edge を抽出できる。
- `.private/` の内容が index されない。
- `projects/.../sources/**/extracted/<file-stem>/` と `views/<scope>/` の sample が存在する。
- project initializer が標準 tree を生成できる。

## 5. 最初の Project を作る

project initializer を実行します。

```bash
scripts/knowledge/init-work-project.sh customer-portal "顧客ポータル"
```

引数:

| 引数 | 例 | 用途 |
|---|---|---|
| project slug | `customer-portal` | directory 名。英小文字、数字、`-` を使う |
| 表示名 | `"顧客ポータル"` | MOC のタイトル |

生成される tree:

```text
knowledge/work/projects/customer-portal/
├── overview.md
├── .templates/
│   └── meeting.md.template
├── meetings/
├── sources/
│   └── documents/
│       ├── 01-要件定義/
│       ├── 02-基本設計/
│       ├── 03-詳細設計/
│       ├── 04-チャットメッセージ/
│       └── 99-その他/
├── decisions/
├── concepts/
└── worklog/
```

`overview.md` は project の MOC です。作成直後に以下を更新します。

- 現在の状態
- 未解決事項
- 関連する source、meeting、worklog、decision、concept への wikilink

`knowledge/work/projects/example-project/` は動作確認用の sample fixture です。新規 project のコピー元にはしません。

## 6. Project を Commit して反映する

作成した project page を commit します。

```bash
git add knowledge/work/projects/customer-portal
git commit -m "docs: add customer portal work brain"
```

commit 後に通常 maintenance を実行します。

```bash
scripts/knowledge/maintain-gbrain-work.sh
```

完了時に以下が表示されます。

```text
work brain maintenance completed
```

maintenance は commit 済みの Markdown だけを差分反映します。未 commit の `knowledge/work/` 差分がある場合は停止します。

## 7. 外部 Repository から Project Knowledge を参照する

必要な repository から project-local knowledge を symlink します。

```bash
cd /path/to/external-project
ln -s \
  /path/to/agent-knowledge-base/knowledge/work/projects/customer-portal \
  knowledge
```

外部 repository から見えるもの:

```text
knowledge/
  overview.md
  meetings/
  sources/
    documents/
      ...
        overview.md
        extracted/
  worklog/
  decisions/
  concepts/
```

外部 repository から見えないもの:

```text
knowledge/work/.raw/
knowledge/work/.artifacts/
knowledge/work/.private/
knowledge/work/_inbox/
```

加工済み資料だけを狭く参照したい場合は、`sources/` だけを symlink できます。

```bash
ln -s \
  /path/to/agent-knowledge-base/knowledge/work/projects/customer-portal/sources \
  docs/project-knowledge
```

## 8. 最初の資料を取り込む

未処理資料は root inbox へ置きます。

```text
knowledge/work/_inbox/
```

例:

```bash
cp /path/to/基本設計書_v1.xlsx knowledge/work/_inbox/
```

その後、coding agent に docs-processing を明示的に依頼します。

```text
_inbox に追加した基本設計書を docs-processing してください。
customer-portal に関係する資料です。
```

docs-processing 成功後の配置:

```text
knowledge/work/
  .raw/
    projects/customer-portal/...       # raw 原本。Git・gbrain index 対象外
  projects/customer-portal/
    sources/
      documents/.../
        overview.md                    # source の入口
        extracted/
          <file-stem>/
            *.md                       # docs-processor の抽出結果
        views/
          <scope>/
            yymmdd_<slug>.*            # 人間用 view
```

raw は必要になった時だけ取り込みます。raw を取得した場合は、同じ処理で extracted Markdown を生成します。

処理に失敗した資料や分類できない資料は `_inbox/` に残します。

## 9. 最初の Meeting を追加する

project-local meeting template をコピーします。

```bash
mkdir -p knowledge/work/projects/customer-portal/meetings/weekly-sync/26/06
cp \
  knowledge/work/projects/customer-portal/.templates/meeting.md.template \
  knowledge/work/projects/customer-portal/meetings/weekly-sync/26/06/260601_1030_weekly-sync.md
```

meeting page のタイトル、開始日時、要約、決定事項、フォローアップを更新します。

命名規約:

```text
meetings/<meeting-slug>/yy/mm/yymmdd_hhmm_<title>.md
meetings/<meeting-slug>/yy/mm/yymmdd_<title>.md        # 開始時間が不明な場合
```

文字起こし、user notes、Copilot summary などの raw は project page へ直接置かず、資料と同様に `.raw/` 側で扱います。

## 10. 日常運用

### Task 開始時

1. gbrain の search、graph、query で関連 knowledge を確認する。
2. 関連する project、source、worklog、concept を読む。
3. 参照した knowledge を brain 外の task workspace に記録する。

### Task 完了・Review 提出・重要 Checkpoint 時

brain 外の task workspace から、再利用する情報だけを `projects/<project>/worklog/...` に投影します。

```text
task.md
  -> 要約
  -> 参照した knowledge
  -> 成果物
  -> 再利用メモ
  -> timeline
  -> projects/<project>/worklog/...md
```

複数 task や複数 project で再利用できる判断、手順、注意事項は `concepts/` に昇格します。

### Markdown 更新後

```bash
git add knowledge/work
git commit -m "docs: update work brain"
scripts/knowledge/maintain-gbrain-work.sh
```

## 11. MCP Server を利用する場合

coding agent から gbrain MCP を利用する場合は、ローカル MCP server を起動できます。

```bash
GBRAIN_HOME="$PWD/.gbrain-work" bun run gbrain/src/cli.ts serve
```

PGLite は単一 writer 向けです。大きな sync、bootstrap、maintenance を行う前に MCP server を停止してください。

## 12. 現時点で手動の処理

以下は初期運用では自動実行されません。

- `_inbox/` の自動監視
- docs-processing の自動実行
- task workspace から brain worklog への同期 skill
- 1 日 1 回の reconciliation batch
- OS scheduler
- upstream gbrain の `dream` / `autopilot` cycle

まずは 1 project で手動運用し、必要性が確認できたものから自動化します。

## 13. 困った時の確認

| 目的 | コマンド |
|---|---|
| derived DB を再構築する | `scripts/knowledge/bootstrap-gbrain-work.sh` |
| 通常の差分反映を行う | `scripts/knowledge/maintain-gbrain-work.sh` |
| 構成、検索、除外ルールを確認する | `scripts/knowledge/verify-gbrain-work.sh` |
| project 雛形を検証する | `scripts/knowledge/test-init-work-project.sh` |
| Git の未 commit 差分を確認する | `git status --short` |

詳細:

- [Repository README](../../README.md)
- [Work Brain の一日運用ライフサイクル](../memo/260531/01_work-brainの一日運用ライフサイクル.md)
- [Work Knowledge Vault Design](../design/knowledge-vault-work.md)
- [Work GBrain Architecture](../design/work-gbrain-architecture.md)
- [ADR-0001: Work document intake と GBrain 境界](../adr/0001-work-document-intake-and-gbrain-boundary.md)
- [ADR-0002: Task workspace と brain worklog projection の分離](../adr/0002-task-workspace-and-brain-worklog-projection.md)
