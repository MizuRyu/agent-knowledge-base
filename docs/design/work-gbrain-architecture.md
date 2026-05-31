# Work GBrain Architecture

作成日: 2026-05-26
状態: Draft

## 目的

この文書は、work brain を gbrain ベースで構築する際の技術アーキテクチャを定義する。

設計の主眼は、gbrain の既存 runtime、schema、retrieval、graph、MCP の仕組みをできるだけそのまま使い、work 固有の要件だけを overlay として追加することである。

## 結論

work brain は gbrain を採用する。

採用方針:

- Markdown を system of record とする。
- gbrain DB は derived cache とする。
- DB は初期 PGLite をそのまま使う。
- retrieval / graph / sync / schema / MCP は gbrain の既存実装を踏襲する。
- embedding は hosted provider ではなく local `ruri-v3-310m` を使う。
- 外部 LLM / hosted embedding / hosted reranker は初期無効とし、work brain content は外部 AI provider に送信しない。
- work 固有差分は `.raw`、`.artifacts`、`.private`、role-based pseudonym、project-local worklog、docs-processing 制約だけに絞る。

## Architecture Overview

```text
User / Agent
  |
  | read/write Markdown
  v
knowledge/work/                    # system of record
  RESOLVER.md
  schema.md
  ACCESS_POLICY.md
  projects/
  people/
  companies/
  meetings/
  concepts/
  source/
  .raw/                            # indexed対象外
  .artifacts/                      # indexed対象外
  .private/                        # indexed対象外 / git対象外
  |
  | gbrain import / sync / extract
  v
GBrain Runtime
  PGLite DB                        # derived cache
    pages
    content_chunks
    links
    tags
    timeline_entries
    page_versions
    config
  |
  +-- keyword search
  +-- wikilink / typed edge graph
  +-- hybrid retrieval
  +-- local embedding via ruri-v3
  +-- MCP server
```

## Technical Components

| 領域 | 採用 | 理由 |
|---|---|---|
| Knowledge source of truth | Markdown | 人間と Agent が直接読める。gbrain の system-of-record 方針と一致する。 |
| Runtime DB | PGLite | 初期運用では単一ユーザー・local-first で十分。Postgres / Supabase 移行余地も残る。 |
| Schema | `gbrain-recommended` + work overlay | gbrain の既存 knowledge 構造を使い、独自化を最小化する。 |
| Link / Relation | gbrain wikilink extraction / typed edges | `[[path]]` を graph edge として扱える。手製 graph は作らない。 |
| Search | gbrain keyword + hybrid retrieval | exact search と semantic search を同じ runtime で扱う。 |
| Embedding | local `ruri-v3-310m` | 日本語性能、local-only、実測上の軽さが work brain 要件に合う。 |
| MCP | `gbrain serve` | Agent が brain-first lookup できる入口。 |
| Raw management | `.raw` | raw 原本は knowledge graph 対象外。必要時に extracted Markdown を作る。 |
| Artifact management | `.artifacts` | Word / Excel / PowerPoint / PDF は派生成果物として分離する。 |
| Private context | `.private` | 実名対応・関係性・優先度判断は public brain に出さない。 |

## Data Ownership

gbrain の system-of-record 方針に合わせ、Markdown を正とする。

```text
Markdown files
  = 正

PGLite pages / chunks / links / embeddings
  = Markdown から再構築可能な derived cache
```

DB が壊れた場合は、Markdown から `gbrain sync` / `gbrain extract all` / reindex で復元する。DB を直接編集して knowledge を正規化しない。

## Retrieval Strategy

Agent は以下の順で brain を参照する。

```text
1. gbrain search
   exact / keyword / slug / title / frontmatter

2. graph traversal
   wikilink / typed edge / related page

3. gbrain query
   ruri-v3 local embedding による semantic retrieval

4. external search
   原則禁止。ユーザー明示承認時のみ。
```

使い分け:

- project / meeting / task / source の場所が分かる場合は直接 page を読む。
- 関係性を辿る場合は graph を使う。
- 類似タスク、過去 worklog、表現揺れした資料検索には embedding を使う。
- `.raw`、`.artifacts`、`.private` は retrieval 対象にしない。
- `projects/<project>/sources/**/extracted/<file-stem>/` は docs-processing 済み Markdown として retrieval 対象に含める。
- `projects/<project>/sources/**/views/<scope>/` は人間用 view として retrieval 対象に含める。HTML など Markdown 以外の view は、対応する Markdown から辿る。

## Lifecycle

初回構築では、Git commit 済みの Markdown 正本から derived DB を構築する。

```text
Git init / commit
  -> gbrain init
  -> source add
  -> sync --full --no-embed
  -> extract links / timeline
  -> embed --stale
  -> doctor
```

通常運用では、Markdown の変更を commit してから差分同期する。

```text
Markdown update / commit
  -> sync --no-embed
  -> extract links / timeline
  -> embed --stale
  -> doctor
```

upstream の install guide は初回投入に `import --no-embed` を例示する。work brain では `RESOLVER.md`、`schema.md`、人間向け `index.md` などの metafile を index へ混入させないため、通常 sync と同じ walker を使う `sync --full --no-embed` を初回投入にも使う。

`knowledge/work/` は単独 Git repository ではなく、agent-knowledge-base repository 配下の source directory とする。vendored gbrain には、親 Git repository 配下の source を受理しつつ、差分検出を source directory 内へ限定する local extension を持たせる。これにより、設計文書や runtime 更新を同じ Git repository で管理しても、work brain へ混入しない。

`doctor` は毎回実行し、JSON を診断ログとして表示する。ただし、初期運用では autonomous `dream` / `autopilot` cycle を必須にしないため、`cycle_freshness` の fail だけで bootstrap や maintenance を中断しない。

## Embedding Architecture

embedding は local `ruri-v3-310m` を使う。

根拠:

- 実測メモ: `docs/memo/260526/01_ruri-v3ローカル性能実測.md`
- M4 / 32GB / macOS 15.5 / MPS で、短文 20-35ms、バッチ 64 文で 59 文/s。
- 1 万チャンクの初回 index でも約 3 分見込み。
- 日本語 embedding として JMTEB 平均 77.24。

注意点:

- gbrain clone に `native-ruri` implementation を追加する。
- PGLite の embedding dimensions は `gbrain init` 時点で schema に焼き込まれる。
- `ruri-v3-310m` は 768 dimensions として初期化する。
- ruri runtime は Python JSONL worker として永続起動し、短い idle timeout 後に終了する。

接続方針:

```text
gbrain
  |
  | native-ruri embedding provider
  v
scripts/ruri_embed_worker.py
  |
  v
ruri-v3-310m model on local machine
```

初期実装:

1. gbrain clone 配下に `ruri` recipe と `native-ruri` implementation を追加する。
2. TypeScript 側は persistent worker に JSONL request を送り、Python 側で `sentence-transformers` を使って embedding する。
3. `litellm`、OpenAI-compatible proxy、hosted provider は使わない。

主な変更点:

- `src/core/ai/recipes/ruri.ts`
- `src/core/ai/ruri-embedding-model.ts`
- `src/core/ai/ruri-worker.ts`
- `scripts/ruri_embed_worker.py`
- `test/ai/ruri-recipe.test.ts`

upstream 追従性を保つため、変更範囲は provider recipe、provider registry、embedding model adapter、worker、smoke test に限定する。

## External Dependency Policy

初期方針では、外部 AI provider への送信を避ける。

無効にするもの:

- hosted embedding provider
- hosted reranker
- hosted query expansion LLM
- hosted chat model を使う schema suggest / enrichment
- `litellm` / OpenAI-compatible proxy 経由の外部 provider 呼び出し

許可するもの:

- local PGLite
- local ruri-v3 embedding runtime
- local gbrain CLI / MCP server
- Markdown / Git / filesystem

gbrain のアルゴリズム自体は踏襲するが、外部 provider を呼ぶ設定は work brain の privacy 方針に合わせて明示的に制御する。

## Graph and Relation Policy

gbrain の link extraction を使う。

主な入力:

- Obsidian wikilink: `[[projects/foo]]`
- display wikilink: `[[projects/foo|Foo]]`
- Markdown link
- frontmatter relation
- typed edge convention

work brain では、初期は以下の関係を重視する。

```text
project -> meeting
project -> worklog task
project -> processed source
worklog task -> concept
meeting -> decision / follow-up
source -> project / concept
person role -> project / company
```

実名は使わず、`people/dev-a`、`people/po-a`、`people/client-po-a` のような role-based pseudonym を使う。

## Storage Boundaries

```text
knowledge/work/projects/
  processed Markdown only
  symlink 参照可能

knowledge/work/.raw/
  raw originals
  not indexed
  not git-managed

knowledge/work/.artifacts/
  generated rich documents
  not indexed
  not git-managed

knowledge/work/.private/
  identity map / relationship map
  not indexed
  not git-managed
  not included in outputs
```

外部 repo から symlink する対象は `knowledge/work/projects/<project>/` のみとする。

## Agent Runtime Flow

### 作業開始時

```text
1. RESOLVER.md / schema.md / ACCESS_POLICY.md を確認
2. gbrain search で project / task / source / concept を検索
3. gbrain graph/query で関連 worklog と concept を取得
4. 必要な文脈を読んで作業開始
```

### raw 取り込み時

```text
1. user が _inbox/ に置く、または必要時に取得
2. Agent が checksum、論理資料名、取得元更新日時で重複・版違いを判定
3. Agent が raw を .raw/projects/.../<論理資料名>/ に最新版だけ配置
4. 同時に overview Markdown を projects/<project>/sources/... に作る
5. 詳細な抽出結果がある場合は visible な `extracted/` に作る
6. source page に raw_ref を残す
7. gbrain sync で overview Markdown を index
```

v1 の docs-processing は、専用 local chat LLM daemon ではなく、ユーザー指示を受けた coding-agent / human-in-the-loop による明示処理とする。raw を取得した場合は、同じ処理で extracted Markdown を作ることを制約にする。

### task 完了時

```text
1. task workspace の task.md を読む
2. task.md から brain worklog projection を作成または更新
3. referenced knowledge を brain worklog に wikilink として投影
4. project page / decisions / source / meeting を必要範囲で更新
5. 再利用できる知識を concepts/ に昇格
6. gbrain sync / import / extract
7. 次回以降の検索・query・graph に反映
```

task workspace は operational state、brain worklog は durable knowledge projection とする。詳細は [ADR-0002](../adr/0002-task-workspace-and-brain-worklog-projection.md) を参照する。

## Adoption Decision

gbrain を採用する理由:

- Markdown-first で、user と Agent の両方が扱える。
- PGLite により local-first で始められる。
- pages / chunks / links / timeline / tags が既にある。
- wikilink から graph edge を作れる。
- keyword + vector + graph の retrieval stack がある。
- MCP server として Agent から使える。
- schema pack / resolver により knowledge 構造を運用できる。

代替案を採らない理由:

- Obsidian + 自前 script: runtime / graph / MCP / retrieval を自作する範囲が大きい。
- LlamaIndex / LangChain + vector DB: Markdown knowledge base の運用規約と graph edge を別途設計する必要がある。
- Qdrant / Chroma 単体: semantic search には強いが、resolver / compiled truth / timeline / Agent write policy が不足する。
- SharePoint / Microsoft Graph 中心: raw document 管理には向くが、Agent-maintained knowledge graph には不足する。

## PoC Acceptance Criteria

gbrain 採用を確定するため、PoC では以下を確認する。

- `knowledge/work` を gbrain source として import / sync できる。
- `gbrain-recommended` schema を有効化できる。
- `projects/example-project` が `gbrain search` で見つかる。
- `[[concepts/document-intake-pipeline]]` が edge として辿れる。
- `native-ruri` provider 経由で local `ruri-v3` embedding できる。
- `gbrain query` で過去 worklog / source / concept が semantic retrieval できる。
- `.raw`、`.artifacts`、`.private` が page / chunk / embedding 対象にならない。
- `gbrain serve` 経由で Agent が brain-first lookup できる。
- DB を消しても Markdown から rebuild できる。

## Open Technical Questions

- gbrain の reranker / query expansion を完全無効にするか、local 実装に差し替えるか。
- `.private` を gbrain runtime から完全除外するための `gbrain.yml` / ignore 設定の最小構成。
- project ごとの access control を将来 brain 分離で行うか、source 分離で行うか。
