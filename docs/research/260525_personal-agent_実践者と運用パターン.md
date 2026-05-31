# 秘書 AI Agent を本気で作っている実践者と運用パターン（2026年5月）

**調査日:** 2026-05-25

> この調査は subagent による Web 調査結果を統合・整形したもの。X 投稿 ID・star 数・本番稼働の具体数値は subagent 収集値であり、親（cutoff 2026-01）で裏が取れないものを含む。末尾「出典の確度」参照。

## なぜこの調査か

「本気で秘書 Agent を運用している人」の構成・規律を盗む。理論より、実際に回っている運用パターンを抽出する。

## 実践者

### 1. Garry Tan（YC CEO）— gbrain + gstack + OpenClaw/Hermes
本プロジェクトの主参照。自分の「拡張神経系」として本番運用。subagent 報告では 146,646 ページ / 24,585 人物 / 5,339 社 / 66 cron jobs が稼働（※数値要再確認）。

- **gbrain（記憶層）**: Git+Markdown のブレインリポジトリ + Postgres+pgvector + 40+ skill。人物ページは「compiled truth + timeline」（上部に現在の最良理解、下部に日付付き証跡）。wikilink から正規表現で型付きグラフ（works_at, invested_in 等）を LLM なしで抽出。**tiered enrichment**: 1 回言及→スタブ、3 回→Web/SNS 充実、8 回→フルパイプライン。夜間 cron で重複排除・引用修正・矛盾検出・翌日準備。
- **gstack（開発ハーネス）**: Claude Code を「CEO レビュー / デザイナー / EM / QA」に仕立てる skill 群。
- **5 原則**（`tmp/gbrain/docs/ethos/THIN_HARNESS_FAT_SKILLS.md` に原文）: Skill File / Thin Harness / Resolver / Latent vs Deterministic / Diarization。
- **「二度頼んだら失敗」規律**: 「一度きりの仕事は禁止。繰り返すなら skill 化して cron に乗せろ」を AGENTS.md に明記[X status/2042034964825551072](https://x.com/garrytan/status/2042034964825551072)。
- 出典: [github.com/garrytan/gbrain](https://github.com/garrytan/gbrain) / [TechCrunch 2026-03-17](https://techcrunch.com/2026/03/17/why-garry-tans-claude-code-setup-has-gotten-so-much-love-and-hate/)

### 2. Simon Willison — 個人 LLM CLI とパターンの言語化
秘書そのものより「個人がエージェントを使いこなす規律」の体系化。`llm` CLI（[github.com/simonw/llm](https://github.com/simonw/llm)）、shebang script で LLM を実行可能スクリプト化、"Agentic Engineering Patterns" を整備[simonw.substack.com](https://simonw.substack.com/p/agentic-engineering-patterns)。方針:「生成コードは使う、文章は自分で書く」。

### 3. Rafferty Uy — 「Pepper」（Obsidian + Claude）
名前付き個人秘書。**権限分離が秀逸**: `_agent/`（Pepper 専有: 記憶・スキル・日次）/ `.claude/skills/`（ユーザー主導）/ `CLAUDE.md`（動作マニュアル）。memory は SQLite FTS5 全文検索、セッション開始時に `git pull`+再インデックス。`_agent/recurring-tasks/` で Playbook を無人実行[raffertyuy.com](https://raffertyuy.com/raztype/personal-assistant/)。

### 4. huytieu — COG Second Brain（gstack/gbrain を Obsidian+Git で再実装）
17 skill / 6 worker。Sonnet で I/O、Opus で統合の役割分担。People CRM は gbrain の compiled truth + tiered enrichment を直接参照。ローカル `.md` 中心 + iCloud 同期[github.com/huytieu/COG-second-brain](https://github.com/huytieu/COG-second-brain)。

### 5. smixs — agent-second-brain（Telegram 音声 → 知識化）
音声メモ → 分類 → Todoist/Obsidian/日次レポート。**Ebbinghaus decay memory** の 5 層（Core→Active→Warm→Cold→Archive）と Vault Health Scoring（孤立ノート検出・リンク修復）[github.com/smixs/agent-second-brain](https://github.com/smixs/agent-second-brain)。

### 6. henrydaum — second-brain（エージェント OS）
ローカル常駐。`memory.md`（永続）+ SQLite（履歴）。Timekeeper cron がサブエージェントを起動→履歴読込→ツール実行→Telegram 通知。実行中にツール/タスクをライブロード[github.com/henrydaum/second-brain](https://github.com/henrydaum/second-brain)。

## 共通して見られる運用パターン

| パターン | 内容 | 採用例 |
|---|---|---|
| **Thin harness + Fat skills** | ハーネスは薄く、判断は Markdown skill に集約 | gbrain, gstack, Hermes, COG |
| **「二度頼んだら失敗」規律** | 繰り返しは即 skill 化 + cron。AGENTS.md に明記 | Garry Tan, Hermes |
| **People pages / CRM** | 人物・企業を MD ページ管理、tiered enrichment | gbrain, COG, Pepper |
| **Cron-driven enrichment** | 夜間自動で重複排除・矛盾検出・翌日準備 | gbrain(66 jobs), Hermes |
| **Memory tiering** | 重要度・鮮度で記憶を階層化 | gbrain, smixs(Ebbinghaus) |
| **Compiled truth + timeline** | 上部に現在の理解、下部に日付付き証跡 | gbrain, COG |
| **Agent 専有領域の分離** | `_agent/` をユーザー領域と物理分離、自由書込許可 | Pepper, Hermes |
| **Resolver(ルーティング)** | タスク型→skill/doc の事前ルーティング | gbrain, gstack |
| **Skill 自動生成** | 成功ワークフローから skill を自動抽出 | Hermes |

## 真似すべき具体的プラクティス

1. **「二度頼んだら失敗」を AGENTS.md に明記**: 同じ依頼が二度来た時点で skill 未整備＝設計失敗、と規律化。
2. **People pages を compiled truth + timeline で**: 上部=現在の理解、下部=日付付き履歴。wikilink で自動グラフ化、tiered enrichment で維持コスト削減。
3. **Resolver を L1/L2/L3 の 3 層に**: L1 常時(~200 行, タスク→skill ポインタ) / L2 索引 / L3 実 skill。
4. **Cron を「決定論」と「判断」に分離**: SQL・集計は LLM トークンなしの決定論実装、矛盾検出・要約・統合だけ LLM。
5. **Agent 専有フォルダを物理分離**: `_agent/` を分け、エージェントに記憶・skill の自由書込を許可。ユーザー領域は明示許可制。これでセッション跨ぎの継続性が生まれる。

## 出典の確度

- **確度高**: Garry Tan / gbrain / Simon Willison / `llm` CLI の存在と性格。各実践者の GitHub リポジトリ群。
- **要再確認**: Garry Tan の本番稼働数値（14 万ページ等）、X 投稿 ID、gstack の star 数、Hermes Agent の規模。geohot / swyx の秘書 agent 運用は subagent が「未確認」と明記。

**最終更新日:** 2026-05-25
