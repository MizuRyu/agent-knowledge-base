# Codex CLI による GBrain LLM 処理代替設計

作成日: 2026-05-31
状態: Draft

## 目的

work brain では、gbrain runtime が OpenAI API、Anthropic API、Voyage API、ZeroEntropy API などの hosted AI provider API を直接呼び出して API 課金が発生する経路を使わない。

一方で、facts 抽出、session からの page 生成、atom 抽出、concept 生成、pattern 検出などは LLM 的な判断を必要とする。これらは、gbrain の直接 API 呼び出しではなく、shell から明示的に起動する Codex CLI job として代替する。

この設計の主眼は、API 課金ルートを gbrain runtime から排除しつつ、upstream gbrain 更新時の conflict を最小化することである。

## 前提

- `gbrain/` は upstream `garrytan/gbrain` を vendor として取り込んだ subtree である。
- upstream 追従時に conflict を避けるため、`gbrain/src/**` の直接変更は最小化する。
- gbrain の Markdown / PGLite / graph / search / sync / extract / local embedding は引き続き利用する。
- embedding は local `ruri-v3-310m` を使う。
- reranker、query expansion、hosted OCR など hosted provider 依存機能は work brain の通常運用では無効化する。
- Codex CLI は API provider ではなく、user が利用している local shell command として扱う。

## 対象ユースケース

### 会話ログから facts 抽出

現状の gbrain では、conversation / transcript から fact rows を抽出する処理が LLM を使う。

Codex 代替では、conversation segment を input として渡し、Codex が `facts.json` を生成する。

出力は schema validation 後に gbrain の facts fence または facts DB 反映処理へ渡す。

### session から page 生成

現状の `synthesize` phase は、session / transcript から reflection、original、people などの page を生成する。

Codex 代替では、session bundle と出力先候補を input とし、Codex が Markdown page proposal を生成する。

自動反映は最初から行わない。proposal を検証し、必要に応じて user または coding agent が採用する。

### atom 抽出

現状の `extract_atoms` phase は、page から atom-shaped insight を抽出する。

Codex 代替では、対象 page の compiled truth と frontmatter を input とし、Codex が `atoms.jsonl` を生成する。

atom は concept synthesis の入力になるため、出力 schema は厳格にする。

### concept 生成・昇格

現状の `synthesize_concepts` phase は、atom group から concept page を生成し、T1/T2 では LLM narrative を作る。

Codex 代替では、atom group、関連 worklog、既存 concept の候補を input とし、Codex が concept Markdown proposal を生成する。

最初の実装では、既存 concept の直接上書きはしない。新規 proposal または patch candidate として保存する。

### pattern 検出

現状の `patterns` phase は subagent job を使い、recurring pattern を検出する。

Codex 代替では、gbrain search / graph / worklog から deterministic に候補 context を集め、Codex が pattern candidates を生成する。

pattern は誤検出が混ざりやすいため、初期は candidate 保存までに留める。

### fact の重複・上書き判定

現状の fact classifier は、類似度 fast path の後に LLM で duplicate / supersede / independent を判定する。

Codex 代替では、deterministic な similarity で候補を絞ったうえで、曖昧な候補だけを Codex job に渡す。

頻繁に呼ぶ hot path に Codex を入れると遅くなるため、通常の cycle では batch job として扱う。

## 非対象

以下は初期の Codex 代替対象にしない。

- `gateway.chat()` 全体の provider として Codex CLI を差し込むこと
- search query expansion の Codex 代替
- search intent / cross-modal intent 判定の Codex 代替
- reranker の Codex 代替
- hosted OCR の Codex 代替
- `gbrain agent run` の完全な Codex CLI 化
- subagent tool loop の完全互換実装
- `think`、`brainstorm`、eval / judge 系の移植

これらは work brain の通常 maintenance には必須ではない。必要になった場合は別 spec として扱う。

## 採用方針

### gbrain core を直接置換しない

既存の `gateway.chat()`、`synthesize_concepts.ts`、`patterns.ts` などを直接 Codex CLI 呼び出しに書き換えない。

理由:

- upstream 更新時に conflict が増える。
- gbrain の LLM phase は upstream 側で頻繁に変わりうる。
- `gateway.chat()` 全体を置換すると、検索 expansion など軽い処理まで Codex 起動になり遅くなる。
- tool loop、retry、streaming、schema output、budget tracking など互換範囲が広すぎる。

work brain では、upstream LLM phase を allowlist から外し、Codex CLI を使う work brain 固有 job を外側に追加する。

### 外側の work cycle で orchestration する

Codex 代替処理は gbrain dream に深く埋め込まず、まずは `scripts/knowledge/` 配下の work brain cycle から呼び出す。

```text
scripts/knowledge/run-work-cycle.sh
  -> gbrain sync / extract / embed
  -> worklog-sync
  -> codex job generation
  -> codex job execution
  -> codex output validation
  -> proposal / Markdown / DB 反映
  -> gbrain sync / extract / embed
```

gbrain の built-in `dream` は、work brain では local deterministic な phase だけを使う。

### Codex job はファイル契約にする

Codex CLI との境界は、関数呼び出し互換ではなくファイル契約にする。

```text
.gbrain-work/codex-jobs/
  <job-id>/
    job.json
    input.md
    instruction.md
    output.schema.json
    output.json
    output.md
    status.json
```

`job.json` は job 種別、入力ファイル、期待出力、対象 project、source id、timeout、作成日時を持つ。

`instruction.md` は Codex に渡す作業指示である。Codex は repository を自由編集するのではなく、指定された `output.json` または `output.md` を生成する。

`output.schema.json` がある job は、取り込み前に必ず schema validation を行う。

### Codex CLI 実行は明示的に扱う

gbrain runtime が hosted provider API を直接呼ばないことが目的であり、Codex CLI の shell 起動は別経路として許可する。

ただし、Codex CLI job は audit 可能にする。

- job id
- input path
- output path
- command
- started_at / finished_at
- exit code
- output validation result
- adopted / rejected / pending

これらを `status.json` に残す。

## Upstream Conflict 回避

### local patch を増やさない

`gbrain/` に直接入れる変更は、以下のような薄い seam に限定する。

- hosted provider を work brain で使わないための config / guard
- work brain で実行する phase allowlist
- local `ruri-v3-310m` provider
- source scoped sync / strict walker など既存 local extension

Codex CLI runner、job schema、job execution、proposal importer は `gbrain/` の外に置く。

候補:

```text
scripts/knowledge/
  run-work-cycle.sh
  codex-job-runner.sh

scripts/knowledge/codex/
  generate-concept-jobs.ts
  import-concept-proposals.ts
  generate-facts-jobs.ts
  import-facts.ts

knowledge/work/.codex-jobs/       # Git 管理しない場合
.gbrain-work/codex-jobs/          # derived / local runtime state
```

### upstream 追従時の確認項目

upstream gbrain 更新時は、既存 local extension に加えて以下を確認する。

- work brain の phase allowlist が hosted LLM phase を含まない。
- `gbrain sync / extract / embed` が Codex job 成果物を意図通り扱う。
- `ruri-v3-310m` local embedding が維持されている。
- hosted reranker / query expansion / OCR が有効化されていない。
- Codex job runner は `gbrain/src/**` の変更に依存していない。

## Phase Allowlist

work brain の通常 cycle では、以下を許可する。

- sync
- extract links
- extract timeline
- embed with local ruri
- worklog-sync
- deterministic candidate generation
- Codex job runner
- Codex output validation
- Codex proposal import

以下は既定では無効化する。

- synthesize
- extract_atoms
- synthesize_concepts
- patterns
- propose_takes
- grade_takes
- calibration_profile
- conversation_facts_backfill
- subagent
- think / brainstorm / eval / judge 系
- query expansion
- hosted reranker
- hosted OCR

必要になった場合は、既存 phase を有効化するのではなく、Codex job 版の work brain phase を追加する。

## Codex Job 種別

### `facts.extract`

入力:

- conversation segment
- related project / source / worklog
- 既存 facts 候補

出力:

- `facts.json`
- confidence
- source span
- entity candidate
- valid_from / valid_until 候補

### `session.synthesize_pages`

入力:

- session transcript
- target project
- related existing pages

出力:

- Markdown page proposal
- proposed path
- referenced pages
- unresolved questions

### `atoms.extract`

入力:

- page body
- frontmatter
- related concept candidates

出力:

- `atoms.jsonl`
- concept refs
- evidence span

### `concepts.synthesize`

入力:

- atom group
- existing concept candidates
- related worklog

出力:

- concept Markdown proposal
- merge target candidate
- reuse notes
- unresolved conflicts

### `patterns.detect`

入力:

- worklog summaries
- graph neighborhood
- source pages

出力:

- pattern candidates
- evidence links
- confidence
- recommendation: create / merge / ignore

### `facts.classify`

入力:

- incoming fact
- similar existing facts

出力:

- duplicate / supersede / independent
- rationale
- affected fact ids

## Error Handling

- Codex command failure: job を `failed` にして再実行可能にする。
- output schema validation failure: job を `invalid_output` にして取り込まない。
- ambiguous result: proposal として保存し、自動反映しない。
- partial output: schema valid な部分だけを採用しない。job 単位で失敗扱いにする。
- timeout: job を `timed_out` にして次回 cycle では自動再実行しない。

## 受け入れ条件

- gbrain runtime が hosted chat / hosted reranker / hosted OCR を通常 cycle で呼ばない。
- local ruri embedding は維持される。
- Codex CLI を使う処理は job directory に input / instruction / output / status を残す。
- Codex output は schema validation を通過しない限り取り込まれない。
- concept / pattern / session page は初期状態では proposal として保存され、既存 knowledge を直接上書きしない。
- gbrain upstream 更新時に、Codex runner の主要コードが `gbrain/src/**` conflict に巻き込まれない。
- upstream 更新手順に Codex job runner の smoke test が追加される。

## Open Questions

- Codex CLI の非対話実行コマンド形式をどこまで安定前提にできるか。
- Codex job の保存先を `.gbrain-work/codex-jobs/` にするか、`knowledge/work/.codex-jobs/` にするか。
- proposal を Git 管理するか、derived runtime state として扱うか。
- facts を facts DB に直接入れるか、まず Markdown fence に反映してから existing `extract_facts` に任せるか。
- Codex job の user approval gate をどの job 種別に必須化するか。
