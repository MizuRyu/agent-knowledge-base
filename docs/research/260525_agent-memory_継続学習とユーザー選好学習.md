# Agent の継続学習・ユーザー選好学習・Memory（2026年5月）

**調査日:** 2026-05-25

> この調査は subagent による Web 調査結果を統合・整形したもの。末尾の「出典の確度」を必ず参照すること。一部の 2025 年後半〜2026 年の arXiv 番号は未検証を含む。

## なぜこの調査か

秘書 Agent が「使うほど賢くなる」には、(1) 経験からの自己改善、(2) ユーザーの好みの学習、(3) それを保持する memory の 3 つが要る。パラメータ更新（fine-tuning）なしで API ベースの Agent に適用できる手法を中心に押さえる。

## 1. 継続学習・自己改善（パラメータ更新なし）

中心軸は「タスク内改善（intra-task）」か「タスク間転移（inter-task）」か。

- **Reflexion**（NeurIPS 2023）: タスク後に言語的振り返りを生成しエピソード記憶に蓄積、次試行のプロンプトに注入。重みを変えず RL を実現。intra-task 限定[arXiv 2303.11366](https://arxiv.org/abs/2303.11366) / [GitHub noahshinn/reflexion](https://github.com/noahshinn/reflexion)。
- **Voyager**（2023）: 自動カリキュラム + **コードベースのスキルライブラリ** + 反復プロンプト。実行可能コードとしてスキルを蓄積し後続タスクで再利用。初の lifelong learning エージェント[arXiv 2305.16291](https://arxiv.org/abs/2305.16291) / [GitHub MineDojo/Voyager](https://github.com/MineDojo/Voyager)。
- **ExpeL**（AAAI 2024）: 訓練タスクで経験プールを蓄積し、成功軌跡から自然言語インサイトを ADD/UPVOTE/DOWNVOTE/EDIT で動的管理。テスト時に in-context 注入。**inter-task 学習を実現した初期の実用手法**[arXiv 2308.10144](https://arxiv.org/abs/2308.10144)。
- **Generative Agents**（UIST 2023）: Memory Stream（全経験を自然言語記録）→ Reflection（高次抽象を周期生成）→ Planning の 3 層[arXiv 2304.03442](https://arxiv.org/abs/2304.03442)。
- **CLIN**（2023）: 因果的抽象中心の永続テキストメモリ。タスク/環境が変わっても転移可能[arXiv 2310.10134](https://arxiv.org/abs/2310.10134)。
- **SAGE**（Amazon, ※要再確認）: Sequential Rollout で前タスクのスキルを次タスクで再利用、skill-integrated reward でスキル生成を強化[arXiv 2512.17102](https://arxiv.org/abs/2512.17102) / [GitHub amazon-science/SAGE](https://github.com/amazon-science/SAGE)。
- **ReasoningBank**（Google Research, ※要再確認）: contrastive + refinement シグナルで test-time memory を蒸留[Google Research blog](https://research.google/blog/reasoningbank-enabling-agents-to-learn-from-experience/)。
- **ReMe**（2025-2026, ※要再確認）: 多面的蒸留 → 文脈適応的再利用 → 効用ベース剪定（古いメモリを自動削除）。静的追記型から進化型 procedural memory へ[arXiv 2512.10696](https://arxiv.org/abs/2512.10696)。

**示唆**: ExpeL 型の「経験プール + インサイト動的管理」はパラメータ更新不要で API ベース秘書に直接適用可。Voyager のスキルライブラリは「thin harness + fat skills」と直接対応。

## 2. ユーザー選好学習・personalization

明示的 fine-tuning なしに、ユーザーの編集・フィードバックから潜在選好を推論し in-context に適用する手法が主流。

- **PRELUDE / CIPHER**（NeurIPS 2024）: ユーザーがエージェント出力を**編集する行為を暗黙フィードバック**とし、過去の編集履歴から潜在選好の説明文を推論して次回プロンプトに注入。fine-tuning 不要、ユーザー数にスケール[arXiv 2404.15269](https://arxiv.org/abs/2404.15269)。
- **User Preference Modeling for Conversational Agents**（2026, ※要再確認）: ユーザー行動を埋め込みに集約、デコード時に per-user 報酬で誘導[arXiv 2603.20939](https://arxiv.org/pdf/2603.20939)。
- **User Personas**（2025, ※要再確認）: 選好データを推論ペルソナで拡張[arXiv 2501.11549](https://arxiv.org/pdf/2501.11549)。
- まとめリスト: [GitHub VanillaCreamer/Awesome-Personalized-LLMs](https://github.com/VanillaCreamer/Awesome-Personalized-LLMs)。

**課題**: 選好の多様性（スタイル/トーン/詳細度）、明示アノテーションの少なさ、ユーザー数増でも再学習なしにスケールする要件。

**示唆**: 「ユーザーが秘書の出力を編集した差分」をイベント化し、PRELUDE 方式で選好ルールを随時更新するだけで継続パーソナライゼーションが成立。

## 3. Agent Memory OSS 比較

| 名前 | メモリ種別 | 永続化 | 特徴 | GitHub | 活発さ(調査時点) |
|---|---|---|---|---|---|
| **Mem0** | Episodic/Semantic/Procedural | Hybrid(vector+graph+KV) | 自己編集メモリ・重複排除。汎用パーソナライズ向け | [mem0ai/mem0](https://github.com/mem0ai/mem0) | ~56K★ / 毎日更新 |
| **Letta(旧MemGPT)** | Core/Archival/Recall | 3層永続化 | OS のメモリ管理に着想。層間移動を自律管理。LongMemEval 上位 | [letta-ai/letta](https://github.com/letta-ai/letta) | ~23K★ |
| **Zep/Graphiti** | Episodic/Semantic/Temporal | Temporal KG(bi-temporal) | 事実の**有効期間**を管理。ファクト変化の推論に強い | [getzep/graphiti](https://github.com/getzep/graphiti) | ~24K★ |
| **LangMem** | Episodic/Semantic/Procedural | モジュラー | procedural memory で **system prompt を自動更新** | [langchain-ai/langchain](https://github.com/langchain-ai/langchain) | (LangChain 同梱) |
| **Cognee** | Graph+Vector+Relational | Poly-store(local-first) | ECL パイプライン。Ollama 対応でオフライン可 | [topoteretes/cognee](https://github.com/topoteretes/cognee) | ~17K★ |

※ LongMemEval のスコア（Letta 83.2% / Zep 63.8% / Mem0 49% など）は subagent 報告値で出典により差がある。**要再確認**。

## 4. 「学びを skill に書き戻す自己改善ループ」の裏付け

「経験 → 抽象 → ファイル書き戻し → 次回自動適用」ループは複数で実証済み。

- **Voyager**: スキルを実行可能コードとして永続化、類似度検索で再利用。
- **ExpeL**: インサイトリストを ADD/UPVOTE/DOWNVOTE/EDIT で動的管理。
- **LangMem procedural memory**: `update_system_prompt` で system prompt を実行時に書き換え[LangChain blog: LangMem SDK launch](https://www.langchain.com/blog/langmem-sdk-launch)。
- **ReMe**: utility-based refinement で低効用メモリを自動剪定。
- **BerriAI/self-improving-agent**（OSS）: エージェントが diff 提案 → 人間承認 → PR 作成[GitHub](https://github.com/BerriAI/self-improving-agent)（※存在要再確認）。

これは gbrain の「事後フィードバックを diarize → 新ルール抽出 → skill に書き戻す」（`tmp/gbrain/docs/ethos/THIN_HARNESS_FAT_SKILLS.md` の YC Startup School 例、"OK" 率 12%→4%）と同じ構造。

## 練度を磨く仕組みへの直結示唆

1. **編集差分を暗黙フィードバックに（PRELUDE/CIPHER）**: ユーザーが秘書の下書きを直すたびに差分を捕捉し、潜在選好ルールを推論して preference ブロック / skill に自動反映。
2. **経験プール + インサイト動的管理（ExpeL 型）**: タスクログ（成功/失敗）を蓄積、定期バッチでインサイト抽出・ADD/DOWNVOTE/EDIT。CLI + cron の軽量設計に合う。
3. **Skill 自動更新ループ（Voyager + LangMem 型）**: 繰り返しタスクの SKILL.md に「最終実行結果 / ユーザー修正 / 推奨パラメータ変更」を持たせ、完了フックで書き戻す。
4. **Procedural Memory の剪定で腐敗防止（ReMe 型）**: ルールに効用スコアを付け、未使用・矛盾ルールを自動削除。frontmatter（`use_count` / `last_used` / `score`）で外部 DB なしに実現。
5. **Temporal KG で「いつ変わったか」を追跡（Zep/Graphiti 型）**: 好みは変化する。YAML タイムスタンプで bi-temporal を模倣し、古いルールを低優先化して選好ドリフトに対応。

## 出典の確度

- **確度高**: Reflexion(2303.11366) / Voyager(2305.16291) / ExpeL(2308.10144) / Generative Agents(2304.03442) / CLIN(2310.10134) / PRELUDE(2404.15269) / Mem0 / Letta / Zep(Graphiti) / Cognee の存在。
- **要再確認**: SAGE(2512.17102) / ReMe(2512.10696) / ReasoningBank / 2026 年 personalization 論文(2603.20939 等) / LongMemEval の具体スコア / BerriAI self-improving-agent の実在。

**最終更新日:** 2026-05-25
