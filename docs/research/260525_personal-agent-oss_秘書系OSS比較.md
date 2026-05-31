# 秘書・Personal Assistant 系 OSS 比較（2026年5月）

**調査日:** 2026-05-25

> この調査は subagent による Web 調査結果を統合・整形したもの。**star 数・最終更新・新興 OSS の実在性は subagent 収集値であり、親の知識（cutoff 2026-01）で裏が取れないものを含む。** 採用判断の前に GitHub で一次確認すること。末尾「出典の確度」参照。

## なぜこの調査か

秘書 Agent を「ゼロから作る」のではなく、既存の thin-harness / memory 基盤に乗せたい（idea/001 の方針）。候補 OSS のアーキ・memory・skill 機構・活発さを横断比較する。

## 比較表

| OSS | 目的 | harness | memory | skill/plugin | 主要連携 | GitHub | ★(調査時点) | ライセンス |
|---|---|---|---|---|---|---|---|---|
| **OpenClaw** | local-first 汎用 personal agent | **Thin**(単一 TS Gateway) | Markdown(SOUL.md+MEMORY.md, append-only) | Skills=MD / Tools=TS / Plugins=npm | Gmail, GCal, Slack, WhatsApp, Telegram, MCP 70+ | [openclaw/openclaw](https://github.com/openclaw/openclaw) | 巨大(※後述) | MIT |
| **gbrain** | agent 用の知識/memory 基盤 | Fat skills / thin harness | Git+Markdown 3層(Repo / pgvector / Skills) | 40+ MD ワークフロー | Gmail, GCal, 会議録, cron | [garrytan/gbrain](https://github.com/garrytan/gbrain) | ~14-19K | MIT |
| **Hermes Agent** (Nous) | 常駐型自律 agent | Thin | user.md+memory.md, Soul | YAML+MD skill, 自動スキル生成 | cron, gbrain interop | [nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent) | 大(※後述) | (要確認) |
| **Khoj** | self-hosted AI second brain | 中(Django) | セマンティック検索+RAG | カスタム agent, automations | Obsidian, Emacs, WhatsApp | [khoj-ai/khoj](https://github.com/khoj-ai/khoj) | ~35K | AGPL-3.0 |
| **Letta(MemGPT)** | ステートフル agent / memory | Fat | OS型3層(core/archival/recall) | tools/subagents | LLM API 全般 | [letta-ai/letta](https://github.com/letta-ai/letta) | ~23K | Apache-2.0 |
| **Mem0** | memory layer(ライブラリ) | very thin | multi-signal(semantic+BM25+entity) | なし | LLM 非依存, pip/npm | [mem0ai/mem0](https://github.com/mem0ai/mem0) | ~57K | Apache-2.0 |
| **Cognee** | KG memory(ライブラリ) | thin | ECL, vector+KG(Neo4j/Kùzu) | MCP server | vector DB 各種 | [topoteretes/cognee](https://github.com/topoteretes/cognee) | ~17K | Apache-2.0 |
| **Leon** | self-hosted personal assistant | 中(TS) | 3層 layered memory | packages/modules | 限定的 | [leon-ai/leon](https://github.com/leon-ai/leon) | ~17K | MIT |
| **Open Interpreter** | 自然言語でコード実行 | 中(Python) | なし(セッション内) | なし | ローカル OS 操作 | [openinterpreter/open-interpreter](https://github.com/openinterpreter/open-interpreter) | ~64K | AGPL-3.0 |
| **Goose**(AAIF) | 汎用タスク/コーディング agent | Thin(Rust) | なし(セッション内) | MCP 70+ | GitHub/Slack/Jira/MCP | [aaif-goose/goose](https://github.com/aaif-goose/goose) | ~46K | Apache-2.0 |

## 注目 3 プロジェクト

### OpenClaw — harness 本体候補
[openclaw/openclaw](https://github.com/openclaw/openclaw) | MIT

local-first の personal AI agent。単一 TypeScript Gateway プロセスが全チャネルをルーティングする極薄ハーネスで、Skills=Markdown / Tools=TS 関数 / Plugins=npm の 3 層。「One process. One port.」が Garry Tan の "thin harness, fat skills" と一致[Data Science Collective の解説記事](https://medium.com/data-science-collective/355k-github-stars-in-5-months-17-defense-rate-the-complete-honest-guide-to-openclaw-28d2f59598e1)。memory は SOUL.md（人格・制約）+ MEMORY.md（長期）+ append-only daily ログでテキストとして人間可読。

> ⚠️ subagent は star 数 ~375K（5 ヶ月で GitHub 最多級）と報告。**この数値は親では裏が取れず、過大の可能性。** プロジェクトの実在と設計思想は複数記事で整合するが、規模指標は GitHub で要再確認。

### gbrain — memory/knowledge 層候補（本プロジェクトの主参照）
[garrytan/gbrain](https://github.com/garrytan/gbrain) | MIT

YC CEO Garry Tan が自分の agent のために構築・公開した knowledge memory 基盤[MarkTechPost 2026-05-22](https://www.marktechpost.com/2026/05/22/a-step-by-step-coding-tutorial-to-implement-gbrain-the-self-wiring-memory-layer-built-by-y-combinators-garry-tan-for-ai-agents/)。3 層（Git+Markdown の Repo / Postgres+pgvector の hybrid 検索 / 40+ skill）。LLM コールなしで wikilink から型付きグラフエッジを自動抽出する自己配線が特徴。**Executive Assistant Pattern / email→entity page / 会議録→attendee page が実装済みで「秘書」ユースケースに最も近い唯一の OSS。** 既に `tmp/gbrain/` にクローン済み。

### Hermes Agent（Nous Research）— 5 本柱が参考
[nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent)（※実在・規模は要確認）

常駐型自律 agent。5 本柱: Memory(`user.md`+`memory.md`) / Skills(YAML+MD, **成功ワークフローから自動スキル生成**) / Soul(個性) / Crons(自然言語で定期タスク) / 自己改善ループ。gbrain interop あり（OpenClaw からの設定・記憶・スキル移行コマンド）[hermes-agent.org](https://hermes-agent.org/) / [MindStudio 解説](https://www.mindstudio.ai/blog/hermes-agent-5-pillar-architecture-memory-skills-soul-crons)。**「自動スキル生成」と「自己改善ループ」は練度テーマに直結。**

## 秘書 Agent 構築で参考にすべき上位 3 つ

1. **OpenClaw** — harness 本体。thin harness + Markdown skill が設計思想と完全一致。Gmail/GCal/Slack 連携 skill が既存。
2. **gbrain** — memory/knowledge 層。秘書ユースケースで設計された唯一格。people CRM・compiled truth + timeline。Garry Tan の本番構成は OpenClaw(harness) × gbrain(brain)。
3. **Mem0** — Git+Markdown より軽く memory layer だけ足したい時の現実解。LLM 非依存、pip/npm。

> 補足: Letta/Zep/Cognee は「memory コンポーネント」、Goose/Open Interpreter は「実行ハーネス（秘書連携は別途）」という位置づけ。秘書の people/relationship 管理まで含めて設計されているのは gbrain が頭一つ抜けている。

## 出典の確度

- **確度高（親の知識と整合）**: gbrain, Mem0, Letta(MemGPT), Khoj(YC W24), Cognee, Leon, Open Interpreter, Goose の存在とおおまかな性格。
- **要再確認**: OpenClaw / Hermes Agent / gstack の存在は複数記事で言及されるが、**star 数・最終更新・ライセンスの具体値は親では未検証**。Goose の AAIF 移管、各 star 数。採用前に GitHub 一次確認。

**最終更新日:** 2026-05-25
