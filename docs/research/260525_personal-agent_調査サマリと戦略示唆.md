# 秘書 Agent「練度を磨く仕組み化」調査サマリと戦略示唆（2026年5月）

**調査日:** 2026-05-25

> 4 本のテーマ別調査を束ねた索引兼サマリ。各 doc は subagent の Web 調査を統合したもので、出典の確度に差がある（各 doc 末尾を参照）。**戦略を確定する前に、要再確認とマークした一次情報を検証すること。**

## 索引

- [再現性と評価フレームワーク](./260525_agent-eval_再現性と評価フレームワーク.md)
- [継続学習とユーザー選好学習](./260525_agent-memory_継続学習とユーザー選好学習.md)
- [秘書系 OSS 比較](./260525_personal-agent-oss_秘書系OSS比較.md)
- [実践者と運用パターン](./260525_personal-agent_実践者と運用パターン.md)

## 1 行サマリ

「練度を磨く」とは、研究・OSS・実践者の三方向で見ると **(A) 評価ゲート / (B) 自己改善ループ / (C) 選好・関係性 memory** の 3 つの輪を回すこと。3 つとも、API ベース・Markdown 中心・パラメータ更新なしで実装できる手法が出揃っている。

## 練度を磨く「3 つの輪」

### 輪 A：評価ゲート（変更が改善か退化かを判定）
- LLM は非決定的。**単一実行比較は無意味、N≥5 回 + bootstrap 信頼区間**が標準（[eval doc §1](./260525_agent-eval_再現性と評価フレームワーク.md)）。
- 実装形: **capture → replay → gate**。本番トレースを JSONL 蓄積 → ベースライン化 → 変更後 replay → 閾値割れで止める。gbrain は既に実装（Jaccard / top-1 安定性 / latency、`tmp/gbrain/docs/eval-bench.md`）。
- 秘書ドメインの評価軸は τ²-bench 流の **Task Completion + Policy Adherence**（上司の意向に従いつつツールを正しく使えたか）。
- LLM-as-Judge を使うなら**バイアス対策必須**（複数回採点・字数上限ルーブリック・judge 固定）。

### 輪 B：自己改善ループ（使うほど賢く）
- パラメータ更新なしの王道は **ExpeL（経験プール + インサイトを ADD/UPVOTE/DOWNVOTE/EDIT）** と **Voyager（スキルをコードとして蓄積・再利用）**（[memory doc §1,§4](./260525_agent-memory_継続学習とユーザー選好学習.md)）。
- ユーザー選好は **PRELUDE/CIPHER：出力の「編集差分」を暗黙フィードバックに**して選好ルールを推論・注入。
- 実装形: 繰り返しタスクの SKILL.md に「最終結果 / ユーザー修正 / 推奨変更」を持たせ、完了フックで**書き戻す**（LangMem の system prompt 自動更新と同型）。gbrain の「フィードバックを diarize → 新ルールを skill に書き戻す」（"OK" 率 12%→4%）と一致。
- 腐敗防止に **ReMe 型の効用ベース剪定**（frontmatter に `use_count`/`last_used`/`score`）。

### 輪 C：選好・関係性 memory（誰が・何を・いつ）
- 実践者の定番は **compiled truth + timeline**（上部=現在の理解、下部=日付付き証跡）+ **tiered enrichment**（言及回数で充実度を段階化）（[実践者 doc](./260525_personal-agent_実践者と運用パターン.md)）。
- 好みは変わる → **Zep/Graphiti の bi-temporal**（事象発生時刻 + 取込時刻）を YAML タイムスタンプで模倣し、古いルールを低優先化。
- memory 基盤候補は gbrain（秘書ユースケース設計済み・既にクローン済み） > Mem0（軽量 layer）。

## 2. ユーザー構想とのマッピング

| idea/001・ADR-0001 の要素 | 調査からの裏付け / 補強 |
|---|---|
| thin harness, fat skills | OpenClaw/gbrain/Hermes/実践者すべてが採用。方向は正しい |
| 決定論優先（骨格は MD/YAML/CLI） | gbrain の Latent vs Deterministic、cron の決定論/判断分離と一致 |
| Skill 12 種（daily-briefing 等）| gbrain Executive Assistant Pattern、Hermes 自動スキル生成が雛形 |
| 権限 4 段階（Read/Draft/Approval/Auto）| Pepper の `_agent/` 物理分離が具体例 |
| brain 構造（personal/work/shared）| gbrain 3 層 + compiled truth + timeline で具体化可 |
| **（構想に薄い）練度を磨くループ** | **本調査の輪 A/B が直接これを埋める。Phase 3 の「skill を作る」に、評価ゲートと自己改善を足す** |

## 3. ギャップ（構想に足りないもの）

- idea/001 Phase 1-5 は**構築（作る）中心**。「測る・直す・自己改善させる」ループが未設計。
- → **輪 A（評価ゲート）と輪 B（自己改善）を Phase に追加**するのが本調査の最大の含意。
- ADR-0001（資料 intake）は輪 C の入口だが、選好学習・効用剪定の記述はまだ無い。

## 4. 戦略オプション（次に設計する候補）

1. **評価ゲート先行**: 先に「skill の良し悪しを測る基準（EVALS.md）+ capture→replay→gate」を作る。以後の全 skill 改修がこのゲートを通る。練度の土台。
2. **自己改善ループ先行**: ExpeL/PRELUDE 型の「経験プール + 編集差分 → skill 書き戻し」を作る。早く「賢くなる実感」が出る。ただし評価ゲートが無いと改善の検証ができない。
3. **memory（輪 C）先行**: compiled truth + timeline の people CRM を gbrain ベースで先に立てる。秘書の即効性は高いが「磨く」より「土台作り」寄り。
4. **gbrain/OpenClaw 実地検証先行**: `tmp/gbrain` を実際に動かし、eval/calibration/skill の機構を体験してから設計に落とす。

> 依存関係: 輪 B（自己改善）の効果検証には輪 A（評価ゲート）が要る。**A → B の順、または A と B を小さく同時**が筋。C は土台で並行可。

## 5. 出典の確度（総括）

- **確度高**: 基礎研究（Reflexion/Voyager/ExpeL/Generative Agents/PRELUDE）、主要 eval ベンチ（τ-bench/τ²-bench/AgentBench/Inspect AI）、主要 memory OSS（Mem0/Letta/Zep/Cognee/Khoj）、gbrain・Garry Tan の存在。
- **要再確認**: 2025 後半〜2026 の arXiv 番号（SAGE/ReMe/ReasoningBank/2026 personalization 論文）、OpenClaw/Hermes/gstack の star 数・規模指標、各 2026 年ブログの具体数値、promptfoo 買収説。
- 戦略確定の前に、採用予定の手法・OSS だけ一次情報で再検証すれば十分（全件検証は不要）。

**最終更新日:** 2026-05-25
