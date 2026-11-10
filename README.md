# agent-knowledge-base

`agent-knowledge-base` は、Agent が仕事の knowledge を継続的に蓄積・参照するための local-first workspace です。

Markdown を knowledge の正本とし、[gbrain](./gbrain/) を検索、knowledge graph、semantic retrieval、MCP の runtime として利用します。DB は Markdown から再構築できる derived cache であり、knowledge を DB に直接保存して管理する構成ではありません。

初めて導入する場合は、[初回導入ガイド](./docs/guides/getting-started.md) を上から順に実行してください。

Coding agent は、この repository の作業前に [AGENTS.md](./AGENTS.md) を読み、`knowledge/work/` 更新時は [ACCESS_POLICY.md](./knowledge/work/ACCESS_POLICY.md)、[RESOLVER.md](./knowledge/work/RESOLVER.md)、[schema.md](./knowledge/work/schema.md) に従います。

## 現状

2026-06-01 の初回 commit のまま、更新していません。`knowledge/work/` に入っているのは、架空の `example-project` の見本と雛形だけです。

gbrain は v0.42.1.0 を [gbrain/](./gbrain/) に取り込んでいます（MIT、[gbrain/LICENSE](./gbrain/LICENSE)）。

## 基本方針

- Markdown を system of record とする。
- gbrain の `gbrain-recommended` schema と既存 runtime を基本的に踏襲する。
- PGLite DB と `ruri-v3-310m` embedding をローカルで実行する。
- raw 原本、リッチ成果物、非公開情報を indexed knowledge から分離する。
- task の作業場所と、再利用する knowledge を分離する。
- wikilink を使い、project、meeting、source、worklog、concept の関係を graph edge として辿れるようにする。
- 外部 LLM への送信と外部システムへの書き込みは、既定では行わない。

## アーキテクチャ

```text
User / Coding Agent
  |
  | Markdown を参照・更新
  v
knowledge/work/                  # knowledge の正本
  |
  | sync / extract / embed
  v
gbrain runtime
  |
  +-- PGLite DB                 # derived cache
  +-- keyword search
  +-- wikilink graph
  +-- semantic retrieval
  +-- local ruri-v3 embedding
  +-- MCP server
```

## リポジトリの構成

```text
agent-knowledge-base/
├── README.md
├── docs/
│   ├── adr/                     # 設計判断
│   ├── design/                  # 全体設計・技術設計
│   ├── guides/                  # 初回導入・運用ガイド
│   ├── memo/                    # 運用状況・調査メモ
│   └── superpowers/             # 合意済み spec と実装計画
├── gbrain/                      # vendored gbrain runtime と local extension
├── knowledge/
│   └── work/                    # work brain の Markdown 正本
│       ├── ACCESS_POLICY.md     # private 情報・外部送信・外部書き込みの制約
│       ├── RESOLVER.md          # Agent が保存先を判断するルール
│       ├── schema.md            # page type と Markdown 規約
│       ├── gbrain.yml           # work brain の gbrain 設定
│       ├── index.md             # work brain の人間向け目次
│       ├── _inbox/
│       │   └── README.md        # user が雑に置く未処理 raw の扱い
│       ├── .raw/
│       │   └── projects/        # 処理後に整理した raw 原本
│       ├── .artifacts/
│       │   └── projects/        # Word、Excel、PowerPoint、PDF などの成果物
│       ├── .private/            # 実名対応・関係性などの非公開情報
│       ├── projects/            # project 単位の working knowledge
│       ├── people/              # 匿名化した関係者
│       ├── companies/           # 会社、部署、チーム
│       ├── meetings/            # project 横断の meeting index
│       ├── decisions/           # project 横断の重要な意思決定
│       ├── concepts/            # 横断的に再利用する知識
│       ├── source/              # 複数 project で共有する加工済み資料
│       ├── archive/             # 終了した情報の退避先
│       └── templates/
│           ├── pages/           # project、meeting、source、worklog の雛形
│           └── documents/       # Office 成果物の生成テンプレート置き場
└── scripts/
    └── knowledge/
        ├── bootstrap-gbrain-work.sh
        ├── init-work-project.sh
        ├── maintain-gbrain-work.sh
        └── verify-gbrain-work.sh
```

`.raw/`、`.artifacts/`、`.private/` は hidden directory ですが、役割を明示するため tree に含めています。`_inbox/` 直下の未処理 raw は Git 管理しません。

## Knowledge の分類

| 情報 | 保存先 | 用途 |
|---|---|---|
| project の入口・現在地 | `projects/<project>/overview.md` | Agent が最初に読む project page |
| project 固有の会議結果 | `projects/<project>/meetings/` | transcript ではなく加工済み meeting output |
| project 固有の加工済み資料 | `projects/<project>/sources/` | raw から抽出・整理した Markdown |
| task から抽出した作業知識 | `projects/<project>/worklog/` | task workspace から同期した knowledge projection |
| project 固有の意思決定 | `projects/<project>/decisions/` | project 内で後から理由を確認する判断 |
| project 固有の概念 | `projects/<project>/concepts/` | その project 内で再利用するルールや知識 |
| project 横断の重要な意思決定 | `decisions/` | 複数 project に影響する判断 |
| 横断的に再利用する知識 | `concepts/` | 複数 task・複数 project で使う判断基準、手順、パターン |
| 複数 project で共有する加工済み資料 | `source/` | project に閉じない参照情報 |

root directory は、最初から埋めるための箱ではありません。Agent は [RESOLVER.md](./knowledge/work/RESOLVER.md) に従い、必要になった時点で分類します。

## 新規 Project の開始

`knowledge/work/projects/example-project/` は、gbrain の import、検索、graph edge 抽出を確認する sample fixture です。新しい project のコピー元にはしません。

initializer で project の MOC と標準 directory を一括生成します。

```bash
scripts/knowledge/init-work-project.sh customer-portal "顧客ポータル"
```

生成される tree:

```text
projects/customer-portal/
├── overview.md                 # project の MOC
├── .templates/
│   └── meeting.md.template     # index 対象外の meeting 雛形
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

`overview.md` の現在の状態と未解決事項を更新してください。meeting page は実際に会議が発生した時点で `.templates/meeting.md.template` から作成します。

```text
meetings/<meeting-slug>/yy/mm/yymmdd_hhmm_<title>.md
meetings/<meeting-slug>/yy/mm/yymmdd_<title>.md        # 時間不明時
```

## 日常運用

### Task 開始時

1. gbrain の search、graph、query で関連 knowledge を確認する。
2. 関連する project、source、worklog、concept を読む。
3. 参照した knowledge を brain 外の task workspace に記録する。

### Raw 資料を受領した時

1. 未処理ファイルを `knowledge/work/_inbox/` 直下に置く。
2. coding agent に docs-processing を明示的に依頼する。
3. docs-processing 成功後に raw 原本を `.raw/projects/<project>/...` に移動する。
4. 加工済みの `overview.md` を `projects/<project>/sources/...` に作成する。
5. docs-processor の抽出結果を `extracted/<file-stem>/` に保存する。
6. 人間用 view が必要な場合は `views/<scope>/yymmdd_<slug>.*` に保存する。

raw を取得した場合は、対応する抽出済み Markdown を同じ処理で作成します。raw 原本は indexed knowledge に入れず、Markdown 化した `extracted/` と `views/` を gbrain から辿れる状態にします。

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

knowledge を commit してから通常 maintenance を実行します。

```bash
git add knowledge/work
git commit -m "docs: update work brain"
scripts/knowledge/maintain-gbrain-work.sh
```

## 運用コマンド

| 用途 | コマンド | 備考 |
|---|---|---|
| 新規 project の雛形生成 | `scripts/knowledge/init-work-project.sh <project-slug> "<表示名>"` | MOC、分類フォルダ、meeting 雛形を生成する |
| 初回構築・DB 再構築 | `scripts/knowledge/bootstrap-gbrain-work.sh` | derived DB を削除して再作成するため、日常運用では使わない |
| 通常の差分反映 | `scripts/knowledge/maintain-gbrain-work.sh` | commit 済み Markdown を sync、extract、embed する |
| 構成・検索・除外ルールの検証 | `scripts/knowledge/verify-gbrain-work.sh` | gbrain 更新後や規約変更後に実行する |

## 重要な運用ルール

- knowledge の正本は Markdown とする。PGLite DB を直接編集しない。
- raw 原本を `projects/` 配下に置かない。
- `.raw` と `.private` の内容を外部 LLM に送信しない。
- 公開 brain page に実名を書かない。役割ベースの仮名を使う。
- `.private` の内容を output、推論ログ、worklog、生成 Markdown、timeline に含めない。
- 外部 issue、SharePoint、Teams、メールへの書き込みは、user の明示的な承認を得てから実行する。
- brain page 間の参照には Obsidian-style wikilink を使う。
- raw 原本やリッチ成果物への参照には `raw://work/...` と `artifact://work/...` を使う。

詳細な保存先ルールは [RESOLVER.md](./knowledge/work/RESOLVER.md)、アクセス制約は [ACCESS_POLICY.md](./knowledge/work/ACCESS_POLICY.md) を参照してください。

## 詳細資料

| 資料 | 内容 |
|---|---|
| [Work Knowledge Vault Design](./docs/design/knowledge-vault-work.md) | vault の構成、各 directory の責務、link policy |
| [Work GBrain Architecture](./docs/design/work-gbrain-architecture.md) | runtime、PGLite、embedding、retrieval、MCP |
| [ADR-0001](./docs/adr/0001-work-document-intake-and-gbrain-boundary.md) | raw 資料と indexed knowledge の境界 |
| [ADR-0002](./docs/adr/0002-task-workspace-and-brain-worklog-projection.md) | task workspace と brain worklog projection の分離 |
| [Work Brain の一日運用ライフサイクル](./docs/memo/260531/01_work-brainの一日運用ライフサイクル.md) | 現在の実装範囲、日常フロー、scheduled 実行の扱い |

## ライセンス

[MIT](LICENSE)。取り込んだ [gbrain/](./gbrain/) は、[gbrain/LICENSE](./gbrain/LICENSE)（MIT）に従います。
