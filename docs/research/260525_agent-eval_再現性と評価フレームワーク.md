# Agent の再現性担保と評価フレームワーク（2026年5月）

**調査日:** 2026-05-25

> この調査は subagent による Web 調査結果を統合・整形したもの。末尾の「出典の確度」を必ず参照すること。一部の 2025 年後半〜2026 年の arXiv 番号・新興ツールの動向は未検証を含む。

## なぜこの調査か

秘書 Agent の「タスクの練度を磨く仕組み化」には、**変更前後で本当に良くなったかを判定する仕組み**が要る。LLM は非決定的なので、単純な before/after 比較は成立しない。再現性の担保と評価フレームワークの最新動向を押さえる。

## 1. 再現性の担保 — 決定論化と統計的評価

### 要点

- `temperature=0` + `seed` 固定は「ベストエフォート再現」に過ぎない。モデルバージョンを固定しないと無意味。
- ハードウェア（GPU 数・バッチサイズ）の違いだけで精度が変動した事例が報告されている。主因は GPU 並列処理での float 加算順序の差。
- **単一実行スコアの報告は統計的に無意味**。標準は N 回実行（3〜10 回）して mean±SD と信頼区間を報告すること。
- Claude は seed 非公開。OpenAI は seed 公開だが、同一 seed でも内部バッチ処理で出力が変わりうる。

### 主要な手法

- 非決定性の数値的ソースの分析。GPU 並列の float 加算順序が主因と特定し、「許容範囲付きの意味的等価性評価」を解決策とする[arXiv 2506.09501](https://arxiv.org/html/2506.09501v2)（※2025）。
- ベンチマークスコアの不確実性定量化。同一プロンプトを複数回評価し bootstrap 信頼区間を計算[arXiv 2410.03492](https://arxiv.org/pdf/2410.03492)。
- pass@k に替わるベイズ的評価フレームワーク（MC サンプリング不要でリーダーボードの順位変動を抑制）[arXiv 2510.04265](https://arxiv.org/pdf/2510.04265)（※要再確認）。

### 秘書 Agent への示唆

スキル改修の効果は単一実行では判定不能。**最低 5 回実行してスコア分布を見て、bootstrap 信頼区間が重なるなら「差なし」**と判定する。

## 2. 主要な評価フレームワーク・ベンチマーク

主要 agent ベンチマークは概ね次に集約される。

| ベンチ | 対象 | 秘書との親和性 | 出典 |
|---|---|---|---|
| **τ-bench / τ²-bench** | ツール×ポリシー遵守、ユーザー協調 | **高**（上司の意向に従いつつツールを使う） | [τ-bench 2406.12045](https://arxiv.org/pdf/2406.12045) / [τ²-bench 2506.07982](https://arxiv.org/pdf/2506.07982) / [GitHub sierra-research/tau2-bench](https://github.com/sierra-research/tau2-bench) |
| **GAIA** | 汎用アシスタント（検索・計算・推論の複合） | 中 | [MarkTechPost 2026-04](https://www.marktechpost.com/2026/04/26/top-7-benchmarks-that-actually-matter-for-agentic-reasoning-in-large-language-models/) |
| **SWE-bench Verified** | コーディング | 低（参考） | 汚染問題で OpenAI がスコア報告停止 |
| **AgentBench** | 8 環境横断（OS/DB/Web 等） | 中 | [arXiv 2308.03688](https://arxiv.org/html/2308.03688v3) |
| **Inspect AI（UK AISI）** | 安全隔離環境での能力/安全評価 | 中（フレームワークとして有用） | [inspect.aisi.org.uk](https://inspect.aisi.org.uk/) / [GitHub inspect_evals](https://github.com/UKGovernmentBEIS/inspect_evals) |

**τ²-bench が秘書ドメインに最も近い。** 「ポリシー（上司の意向・制約）に従いながらユーザーと協調してツールを使う」タスクを Dec-POMDP で評価する設計。`pass^k`（k 回中の安定性）は長期信頼性評価の出発点。

### CI ゲート向けツール（2026 実践）

業界推奨は **「CI ゲート用の軽量ツール + 本番トレース管理プラットフォーム」の 2 ツール体制**[Braintrust: Best AI Eval Tools for CI/CD](https://www.braintrust.dev/articles/best-ai-evals-tools-cicd-2025)。

- **Promptfoo** — YAML でアサーション定義、GitHub Actions で PR ブロック[CI/CD docs](https://www.promptfoo.dev/docs/integrations/ci-cd/)。OSS（MIT）。
- **DeepEval** — Task Completion / Tool Correctness / Goal Accuracy / Plan Adherence など agent 専用メトリクス[decodethefuture.org](https://decodethefuture.org/en/ai-agent-benchmarks-2026/)。
- **Braintrust / Langfuse** — 本番トレースと評価データセットを統合。Langfuse はフル OSS・セルフホスト可。

## 3. Capture → Replay → Gate（本番トラフィックを評価に回す）

2025-2026 の標準パターン:「**本番トレース → 自動キュレーション → eval データセット → CI ゲート**」。本番で失敗したトレースが次のテストケースになり、評価スイートがユーザーの実行動に基づいて育つ。

決定論的リプレイの 7 プリミティブ[sakurasky.com: Deterministic Replay](https://www.sakurasky.com/blog/missing-primitives-for-trustworthy-ai-part-8/):

1. **構造化実行トレース** — 全 LLM/ツール呼び出しを JSONL で追記記録
2. **安定したモデル/ツールのメタデータ** — モデル ID・デコードパラメータ・ツールバージョンを紐付け
3. **リプレイエンジン** — 非決定的操作を記録済み値で置換
4. **決定論的スタブ** — ReplayLLMClient/ReplayToolClient が本番同一出力を返す
5. **Agent ハーネス** — record/replay モードを切替（本体は無改造）
6. **ガバナンス統合** — 監査ログ・ポリシー・安全シグナルをトレースにリンク
7. **回帰テスト** — 過去トレースを「凍結された行動ベースライン」に

サンプリング戦略[Adaline: LLM Agent Evaluation 2026](https://www.adaline.ai/blog/complete-guide-llm-ai-agent-evaluation-2026): 重い evaluator は本番の 5〜10% にだけ、軽量ヒューリスティックは 100% に。

**gbrain も同型のパターンを持つ**: `docs/EVALS.md` を先に読ませ「精度が 2% 以上低下したら revert して調査」というルールを Markdown で管理[gbrain THIN_HARNESS_FAT_SKILLS.md](https://github.com/garrytan/gbrain/blob/master/docs/ethos/THIN_HARNESS_FAT_SKILLS.md)。さらに `gbrain eval capture → replay → gate`（Jaccard / top-1 安定性 / latency）が CI に組まれている（ローカル `tmp/gbrain/docs/eval-bench.md` 参照）。

## 4. 2026 時点で議論されている課題

- **LLM-as-Judge のバイアス**: position bias（順序）、verbosity bias（長文が高評価）、sign-reversal failure。フロンティアモデルでも高度バイアステストで 50% 超のエラー率という報告[Adaline: LLM-as-Judge reliability](https://www.adaline.ai/blog/llm-as-a-judge-reliability-bias)（※詳細 arXiv 番号は要再確認）。緩和策: judge を複数回実行、ルーブリックに字数上限、judge モデルを固定してバージョン管理。
- **ベンチマーク汚染・リワードハッキング**: 人気 OSS が訓練データに混入。SWE-bench は OpenAI がスコア報告停止。
- **長期ホライゾン評価の欠如**: マルチデイセッション + 永続メモリをテストするベンチは 2026 年 5 月時点でほぼ存在しない。秘書 Agent はまさにここが本丸。

## 練度を磨く仕組みへの直結示唆

1. **統計的合否判定**: スキル変更時は最低 5 回実行し mean±SD、bootstrap 信頼区間が重なれば差なし。`docs/EVALS.md` に合格基準を明記。
2. **EVALS.md + 精度閾値で gbrain パターンを踏襲**: スキル別合格基準（「前バージョン比 2% 低下で revert」）を Markdown 規約にし、スキル変更時に必ず参照させる。これが thin-harness 流の CI ゲート。
3. **本番ログの eval 昇格パイプライン**: 「失敗・エスカレーション・修正が必要だった」ケースを JSONL トレース化し、次回 eval に自動追加。実ユーザー行動が eval を育てる。
4. **LLM-as-Judge のキャリブレーション必須化**: 秘書スキルの自動採点に LLM を使うなら、複数回採点・字数上限ルーブリック・judge 固定でバイアスを抑える。
5. **評価軸は Task Completion + Policy Adherence**: τ²-bench に倣い「上司のポリシーに従いつつツールを正しく使えたか」を測る。秘書ドメインに最もマッチ。

## 出典の確度

- **確度高（親の知識と整合）**: Reflexion/Voyager/ExpeL/Generative Agents 系、τ-bench(2406.12045)、τ²-bench(2506.07982)、AgentBench(2308.03688)、Inspect AI、promptfoo/DeepEval/Braintrust/Langfuse の存在。
- **要再確認（親の知識 cutoff 2026-01 を超える/未検証）**: 2025 年後半〜2026 年の arXiv 番号（2510.04265 等）、promptfoo の OpenAI 買収説、各種 2026 年ブログ記事の具体数値。戦略に使う前に一次情報で再確認すること。

**最終更新日:** 2026-05-25
