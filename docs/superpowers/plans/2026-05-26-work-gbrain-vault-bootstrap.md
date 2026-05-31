# Work GBrain-First Vault Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** gbrain の既存 knowledge runtime と recommended schema をベースに、不要な領域を削ぎ落とし、仕事用 `work` brain として import / sync / extract / search / query / graph edge まで動作確認する。

**Architecture:** Markdown repo が system of record、PGLite DB は derived cache という gbrain の思想を維持する。まず upstream gbrain を `gbrain/` に clone / install して runtime を成立させ、`gbrain-recommended` schema pack と skillpack/resolver の考え方を踏襲する。その上で、work 固有差分だけを overlay として追加する。embedding は hosted provider や LiteLLM proxy ではなく、local `ruri-v3-310m` を呼ぶ `native-ruri` provider を使う。完了条件はファイル構造の作成ではなく、gbrain DB に pages / chunks / links / embeddings が作られ、search / query / graph 系コマンドで参照できること。

**Tech Stack:** gbrain CLI, Bun, PGLite, Markdown, schema packs, wikilink extraction, native local ruri-v3 provider, Python JSONL worker, shell script, `fd`, `rg`, `jq`.

---

## Scope Correction

前版 plan は「gbrain 互換っぽい Markdown vault」を作る計画に寄りすぎていた。これは採用しない。

本 plan の方針:

- gbrain を fork / clone したものを基準にする。
- gbrain の `RESOLVER.md`、recommended schema、schema pack、sync/import/extract、link extraction、embedding、MCP/query runtime を中核に置く。
- work 用の独自構造は overlay に限定する。
- DB は PGLite をそのまま使う。
- embedding は local `ruri-v3-310m` native provider を使い、hosted embedding provider / LiteLLM / OpenAI-compatible proxy は使わない。
- `.raw`、`.artifacts`、`.private`、role-based pseudonym、project-local worklog、docs-processing 制約だけを追加差分として扱う。
- 検証は Markdown の存在確認だけではなく、gbrain runtime 上で検索・semantic query・edge 抽出が機能するところまで行う。

## File Structure

Create:

- `scripts/knowledge/bootstrap-gbrain-work.sh`
  - upstream gbrain clone / local install 前提確認、work vault seed、overlay 追加、schema activation、import/sync/extract を実行する。
- `scripts/knowledge/verify-gbrain-work.sh`
  - file layer と gbrain runtime layer の両方を検証する。
- `knowledge/work/gbrain.yml`
  - work source 用 gbrain config。`.raw`、`.artifacts`、`.private` を graph / git 対象から外す。
- `knowledge/work/RESOLVER.md`
  - gbrain recommended resolver をベースに work 固有差分だけ追記した resolver。
- `knowledge/work/schema.md`
  - gbrain recommended schema への参照と work overlay page types。
- `knowledge/work/ACCESS_POLICY.md`
  - `.private`、`.raw`、外部 LLM、匿名化、外部書き込み制約。
- `knowledge/work/index.md`
  - work brain entrypoint。
- `knowledge/work/projects/example-project/index.md`
  - PoC project page。
- `knowledge/work/projects/example-project/meetings/weekly-sync/2026/05/2026-05-26-1030-weekly-sync.md`
  - PoC meeting page。
- `knowledge/work/projects/example-project/worklog/2026/05/2026-05-26/01-basic-design.md`
  - PoC worklog page。
- `knowledge/work/projects/example-project/sources/documents/01-要件定義/example-requirements/index.md`
  - PoC processed source page。
- `knowledge/work/concepts/document-intake-pipeline.md`
  - PoC concept page。

Modify:

- `.gitignore`
  - `tmp/`, `knowledge/work/.raw/`, `knowledge/work/.artifacts/`, `knowledge/work/.private/`, generated rich documents を除外する。
- `docs/design/knowledge-vault-work.md`
  - gbrain-first bootstrap / runtime verification 方針を追記する。

Do not create:

- 独自の graph DB。
- 独自の embedding pipeline。
- gbrain と別系統の resolver runtime。
- project 配下の raw 原本。

---

### Task 1: Confirm gbrain Upstream and Runtime Contract

**Files:**
- Read: `gbrain/docs/GBRAIN_RECOMMENDED_SCHEMA.md`
- Read: `gbrain/docs/architecture/system-of-record.md`
- Read: `gbrain/docs/architecture/brains-and-sources.md`
- Read: `gbrain/docs/architecture/RETRIEVAL.md`
- Read: `gbrain/docs/architecture/schema-packs.md`
- No file changes.

- [ ] **Step 1: Confirm workspace**

Run:

```bash
pwd
```

Expected:

```text
/path/to/work-project
```

- [ ] **Step 2: Ensure upstream gbrain clone exists**

Run:

```bash
test -d gbrain/.git && printf 'gbrain clone exists\n' || git clone --depth 1 https://github.com/garrytan/gbrain.git gbrain
```

Expected when clone already exists:

```text
gbrain clone exists
```

- [ ] **Step 3: Record gbrain revision**

Run:

```bash
git -C gbrain rev-parse --short HEAD
```

Expected: a short git hash.

- [ ] **Step 4: Confirm system-of-record contract**

Run:

```bash
rg -n 'markdown is the source of truth|derived cache|Links|content_chunks|gbrain sync|gbrain extract all' gbrain/docs/architecture/system-of-record.md
```

Expected output includes:

```text
markdown is the source of truth
derived cache
Links
content_chunks
gbrain sync
gbrain extract all
```

- [ ] **Step 5: Confirm gbrain graph / embedding claims**

Run:

```bash
rg -n 'Self-wiring knowledge graph|wikilinks|content_chunks|embedding|graph-query|gbrain query' gbrain/README.md gbrain/docs/architecture/RETRIEVAL.md
```

Expected output includes references to:

```text
Self-wiring knowledge graph
wikilinks
content_chunks
embedding
graph-query
gbrain query
```

### Task 2: Install or Link gbrain CLI Locally

**Files:**
- No repo file changes.
- Possible external change: globally linked `gbrain` CLI through Bun.

- [ ] **Step 1: Check required commands**

Run:

```bash
for cmd in bun git fd rg jq; do command -v "$cmd" >/dev/null && printf '%s ok\n' "$cmd" || printf '%s missing\n' "$cmd"; done
```

Expected:

```text
bun ok
git ok
fd ok
rg ok
jq ok
```

- [ ] **Step 2: Check existing gbrain CLI**

Run:

```bash
command -v gbrain >/dev/null && gbrain --version || printf 'gbrain cli missing\n'
```

Expected if already installed: version output.

Expected if not installed:

```text
gbrain cli missing
```

- [ ] **Step 3: Link gbrain from local clone if CLI is missing**

Run only if Step 2 prints `gbrain cli missing`:

```bash
cd gbrain && bun install && bun link
```

Expected: Bun completes install/link without errors.

- [ ] **Step 4: Confirm gbrain CLI after link**

Run:

```bash
gbrain --version
```

Expected: version output.

### Task 3: Initialize GBrain Runtime with Local ruri-v3 Embedding

**Files:**
- External generated config under `~/.gbrain/`
- No repo file changes.

- [ ] **Step 1: Confirm ruri-v3 local embedding provider design**

Read:

```bash
sed -n '1,220p' docs/design/work-gbrain-architecture.md
sed -n '1,120p' docs/memo/260526/01_ruri-v3ローカル性能実測.md
```

Expected: architecture states that embedding uses local `ruri-v3-310m`, and the performance memo states local use is lightweight enough.

- [ ] **Step 2: Implement local ruri provider**

This plan intentionally does not use hosted embedding providers, LiteLLM, or an OpenAI-compatible proxy. Add a small `ruri` recipe and `native-ruri` implementation to the gbrain clone, backed by a local Python JSONL worker. Keep the change limited to provider recipe / registry / adapter / worker / smoke test so upstream gbrain remains easy to rebase.

Expected: `gbrain providers list` includes `ruri`, and a provider smoke test can return embeddings for a Japanese smoke-test sentence using only local resources.

- [ ] **Step 3: Determine ruri-v3 embedding dimensions**

Run against the local ruri runtime or model config:

```bash
RURI_DIMENSIONS="$(gbrain providers test --model ruri:ruri-v3-310m --json \
  | jq -r 'if .embedding_dimensions then .embedding_dimensions elif .dimensions then .dimensions else (.data[0].embedding | length) end')"
printf '%s\n' "$RURI_DIMENSIONS"
```

Expected: a positive integer dimension. Use this value for `--embedding-dimensions`.

- [ ] **Step 4: Initialize PGLite with local ruri-v3 embedding**

Run:

```bash
gbrain init --pglite --embedding-model ruri:ruri-v3-310m --embedding-dimensions "$RURI_DIMENSIONS"
```

Expected: command exits with status 0 and configures local ruri-v3 embedding.

- [ ] **Step 5: Run gbrain doctor**

Run:

```bash
gbrain doctor --json | jq .
```

Expected: valid JSON with no hosted embedding provider requirement. If doctor reports provider mismatch, repair before importing pages because embedding dimensions are fixed at PGLite init time.

- [ ] **Step 6: Activate recommended schema pack**

Run:

```bash
gbrain schema use gbrain-recommended
gbrain schema active
```

Expected output mentions `gbrain-recommended`.

### Task 4: Create Work Source as a Trimmed gbrain Brain Repo

**Files:**
- Create: `knowledge/work/gbrain.yml`
- Create: `knowledge/work/RESOLVER.md`
- Create: `knowledge/work/schema.md`
- Create: `knowledge/work/ACCESS_POLICY.md`
- Create: `knowledge/work/index.md`
- Create directories: `knowledge/work/projects`, `knowledge/work/people`, `knowledge/work/companies`, `knowledge/work/meetings`, `knowledge/work/concepts`, `knowledge/work/source`, `knowledge/work/archive`, `knowledge/work/_inbox/.raw`, `knowledge/work/.raw/projects`, `knowledge/work/.artifacts/projects`, `knowledge/work/.private`
- Modify: `.gitignore`

- [ ] **Step 1: Create work source directories**

Run:

```bash
mkdir -p knowledge/work/{projects,people,companies,meetings,decisions,concepts,source,archive}
mkdir -p knowledge/work/_inbox/.raw knowledge/work/.raw/projects knowledge/work/.artifacts/projects knowledge/work/.private
```

Expected: command exits with status 0.

- [ ] **Step 2: Create `.gitignore` rules**

Ensure `.gitignore` contains exactly these work brain exclusions:

```gitignore
# Local scratch / upstream investigation clone
tmp/

# GBrain work source sidecars. Markdown pages are system of record.
knowledge/work/.raw/
knowledge/work/.artifacts/
knowledge/work/.private/
knowledge/work/**/*.docx
knowledge/work/**/*.xlsx
knowledge/work/**/*.pptx
knowledge/work/**/*.pdf
knowledge/work/**/*.zip
```

- [ ] **Step 3: Create `knowledge/work/gbrain.yml`**

Create:

```yaml
schema:
  pack: gbrain-recommended

source:
  id: work
  description: Work brain source for local work projects.

sync:
  include:
    - "**/*.md"
  exclude:
    - ".raw/**"
    - ".artifacts/**"
    - ".private/**"
    - "_inbox/.raw/**"
    - "**/*.docx"
    - "**/*.xlsx"
    - "**/*.pptx"
    - "**/*.pdf"
    - "**/*.zip"

db_only:
  - ".private/**"
  - ".raw/**"
  - ".artifacts/**"
```

- [ ] **Step 4: Create `knowledge/work/RESOLVER.md` as gbrain overlay**

Create:

```md
# Work Brain Resolver

This resolver extends gbrain-recommended. Use the upstream gbrain filing rules first, then apply these work-specific rules.

## Work-Specific Decisions

1. Private identity maps, real names, relationship maps, priority heuristics → `.private/`.
2. Unprocessed raw files from the user → `_inbox/.raw/`.
3. Processed raw originals → `.raw/projects/<project>/...`.
4. Generated rich artifacts → `.artifacts/projects/<project>/...`.
5. Project-local working knowledge → `projects/<project>/...`.
6. Role-based people pages only → `people/<role-id>.md`.
7. Companies, departments, teams → `companies/<slug>.md`.
8. Reusable patterns and task learnings → `concepts/<slug>.md`.
9. Shared processed source material → `source/<slug>.md`.

## Hard Constraints

- Do not write real names to public brain pages.
- Do not write `.private` contents to output, worklog, generated Markdown, or timeline.
- Do not place raw originals under `projects/`.
- If raw is fetched, create corresponding extracted Markdown.
- Use wikilinks for brain pages.
- Use `raw://work/...` and `artifact://work/...` refs for sidecars.
```

- [ ] **Step 5: Create `knowledge/work/schema.md`**

Create:

```md
# Work Brain Schema

Base schema: `gbrain-recommended`.

## Overlay Types

- `worklog_task`: Knowledge projection synchronized from an external task workspace under `projects/<project>/worklog/...`.
- `processed_source`: Extracted Markdown source under `projects/<project>/sources/...`.

## Page Contract

- Markdown is the system of record.
- GBrain DB is derived cache.
- Internal links use `[[path]]` or `[[path|Display]]`.
- Compiled truth stays above `---`.
- Timeline stays below `---`.
- raw sidecars are referenced with `raw_refs`.
- generated artifacts are referenced with `artifact_refs`.
```

- [ ] **Step 6: Create `knowledge/work/ACCESS_POLICY.md`**

Create:

```md
# Work Brain Access Policy

## Defaults

- External LLM use is forbidden by default.
- No work brain content is sent to external LLMs by default.
- `.raw` and `.private` must never be sent to external LLMs.
- This approved coding-agent environment may read work brain files for local processing.
- External issue, SharePoint, Teams, and mail writes require explicit user approval.

## Identity

- Public brain pages use role-based pseudonyms such as `dev-a`, `po-a`, `sm-a`, `client-po-a`.
- Real-name mapping lives only in `.private/`.
- `.private` content must not appear in output, inference logs, worklog, generated Markdown, or public timeline entries.
```

- [ ] **Step 7: Create `knowledge/work/index.md`**

Create:

```md
---
type: index
status: active
tags: ["work-brain"]
---

# Work Brain

## Current State

Work brain source for local work projects. This source follows gbrain-recommended and adds a small work overlay for `.raw`, `.artifacts`, `.private`, project-local worklog, and document intake.

## Links

- [[projects/example-project|Example Project]]
- [[concepts/document-intake-pipeline|Document Intake Pipeline]]

---

## Timeline

- 2026-05-26 | Bootstrap — Created work brain source.
```

### Task 5: Create PoC Pages That Exercise GBrain Links and Types

**Files:**
- Create: `knowledge/work/projects/example-project/index.md`
- Create: `knowledge/work/projects/example-project/meetings/weekly-sync/2026/05/2026-05-26-1030-weekly-sync.md`
- Create: `knowledge/work/projects/example-project/worklog/2026/05/2026-05-26/01-basic-design.md`
- Create: `knowledge/work/projects/example-project/sources/documents/01-要件定義/example-requirements/index.md`
- Create: `knowledge/work/projects/example-project/sources/documents/01-要件定義/example-requirements/extracted.md`
- Create: `knowledge/work/concepts/document-intake-pipeline.md`

- [ ] **Step 1: Create PoC directories**

Run:

```bash
mkdir -p knowledge/work/projects/example-project/meetings/weekly-sync/2026/05
mkdir -p knowledge/work/projects/example-project/worklog/2026/05/2026-05-26
mkdir -p knowledge/work/projects/example-project/sources/documents/01-要件定義/example-requirements
mkdir -p knowledge/work/concepts
```

Expected: command exits with status 0.

- [ ] **Step 2: Create project page**

Create `knowledge/work/projects/example-project/index.md`:

```md
---
type: project
status: active
aliases: ["Example Project"]
tags: ["poc"]
---

# Example Project

## Current State

GBrain-first work brain の PoC project。runtime import、wikilink edge extraction、keyword search、semantic query、graph traversal の確認に使う。

## Open Threads

- gbrain runtime で `pages`、`content_chunks`、`links` が作られることを確認する。

## Links

- [[projects/example-project/meetings/weekly-sync/2026/05/2026-05-26-1030-weekly-sync|Weekly Sync]]
- [[projects/example-project/worklog/2026/05/2026-05-26/01-basic-design|Basic Design Task]]
- [[projects/example-project/sources/documents/01-要件定義/example-requirements|Example Requirements]]
- [[concepts/document-intake-pipeline|Document Intake Pipeline]]

---

## Timeline

- 2026-05-26 | Bootstrap — Created PoC project for gbrain runtime verification.
```

- [ ] **Step 3: Create meeting page**

Create `knowledge/work/projects/example-project/meetings/weekly-sync/2026/05/2026-05-26-1030-weekly-sync.md`:

```md
---
type: meeting
status: processed
project: example-project
started_at: "2026-05-26T10:30:00+09:00"
raw_refs:
  - raw://work/projects/example-project/meetings/weekly-sync/2026/05/2026-05-26-1030-weekly-sync
artifact_refs: []
---

# Weekly Sync 2026-05-26 10:30

## Summary

Meeting ingestion の PoC。raw transcript は `.raw` に置き、処理後 meeting note だけを project-local Markdown として残す。

## Decisions

- Meeting output is stored as one project-local Markdown page.
- Raw transcript, user notes, and Copilot summaries are sidecars under `.raw`.

## Follow-ups

- [[projects/example-project/worklog/2026/05/2026-05-26/01-basic-design|Basic Design Task]]

---

## Timeline

- 2026-05-26 | Bootstrap — Created PoC meeting note.
```

- [ ] **Step 4: Create worklog task page**

Create `knowledge/work/projects/example-project/worklog/2026/05/2026-05-26/01-basic-design.md`:

```md
---
type: worklog_task
status: done
project: example-project
artifact_refs:
  - artifact://work/projects/example-project/worklog/2026/05/2026-05-26/01-basic-design/basic-design.docx
tags: ["poc", "worklog"]
---

# Basic Design Task

## User Request

基本設計書作成タスクを模した PoC。user request 原文、status、outputs、reuse notes を `task.md` に集約する。

## Summary

Task execution history is synchronized into a first-class gbrain worklog projection. Future agents should search worklog and concepts before starting similar tasks.

## Current State

Completed for PoC.

## Outputs

- artifact://work/projects/example-project/worklog/2026/05/2026-05-26/01-basic-design/basic-design.docx

## Related Links

- [[projects/example-project|Example Project]]
- [[concepts/document-intake-pipeline|Document Intake Pipeline]]

## Reuse Notes

- For document generation tasks, inspect related `worklog/` pages and `concepts/` first.

---

## Timeline

- 2026-05-26 | Bootstrap — Created PoC worklog task.
```

- [ ] **Step 5: Create processed source page**

Create `knowledge/work/projects/example-project/sources/documents/01-要件定義/example-requirements/index.md`:

```md
---
type: processed_source
status: extracted
project: example-project
category: "01-要件定義"
raw_refs:
  - raw://work/projects/example-project/documents/example-requirements
---

# Example Requirements

## Current State

Raw Office document を Markdown 化した processed source の PoC。

## Links

- [[projects/example-project|Example Project]]
- [[concepts/document-intake-pipeline|Document Intake Pipeline]]

---

## Timeline

- 2026-05-26 | Bootstrap — Created processed source page.
```

- [ ] **Step 6: Create extracted Markdown**

Create `knowledge/work/projects/example-project/sources/documents/01-要件定義/example-requirements/extracted.md`:

```md
---
type: processed_source_extract
status: extracted
project: example-project
---

# Extracted Example Requirements

## Requirements

- Processed Markdown lives under `projects/<project>/sources`.
- Raw originals live under `.raw/projects`.
- Generated rich artifacts live under `.artifacts/projects`.
```

- [ ] **Step 7: Create concept page**

Create `knowledge/work/concepts/document-intake-pipeline.md`:

```md
---
type: concept
status: active
aliases: ["docs-processing", "document intake"]
tags: ["knowledge", "documents"]
---

# Document Intake Pipeline

## Current State

Work documents are split into raw originals, processed Markdown, and generated artifacts. If raw is fetched, extracted Markdown must be generated in the same processing flow.

## Links

- [[projects/example-project|Example Project]]
- [[projects/example-project/sources/documents/01-要件定義/example-requirements|Example Requirements]]

---

## Timeline

- 2026-05-26 | Bootstrap — Promoted document intake rule into reusable concept.
```

### Task 6: Register Work Source and Run GBrain Indexing

**Files:**
- Read/write through gbrain runtime.
- No manual DB edits.

- [ ] **Step 1: Register source if supported by current CLI**

Run:

```bash
gbrain sources add work --path "$(pwd)/knowledge/work" || true
```

Expected: either source is added, already exists, or the command is not available in this gbrain version. If unavailable, continue with explicit import path in Step 2.

- [ ] **Step 2: Import work Markdown**

Run:

```bash
gbrain import "$(pwd)/knowledge/work"
```

Expected: command exits with status 0 and reports imported/indexed Markdown pages. If embedding is disabled, command should still import pages or fail with a clear embedding configuration message. If it fails only because embedding is disabled, run:

```bash
gbrain sync --no-pull --no-embed || gbrain import "$(pwd)/knowledge/work" --no-embed
```

Expected: pages are indexed without embedding.

- [ ] **Step 3: Extract derived knowledge**

Run:

```bash
gbrain extract all || true
```

Expected: command exits with status 0 if extract is available. If this gbrain version does not expose `extract all`, record the CLI error and rely on import/sync link reconciliation.

- [ ] **Step 4: Run sync**

Run:

```bash
gbrain sync --no-pull || gbrain sync
```

Expected: command exits with status 0. If embedding is disabled and sync refuses embedding, use the no-embed variant from Step 2.

### Task 7: Verify Runtime Search, Query, and Link Edges

**Files:**
- No file changes.
- Verifies gbrain DB derived cache.

- [ ] **Step 1: Keyword search project**

Run:

```bash
gbrain search "Example Project"
```

Expected output includes a result for:

```text
projects/example-project
```

- [ ] **Step 2: Keyword search concept**

Run:

```bash
gbrain search "document intake pipeline"
```

Expected output includes:

```text
concepts/document-intake-pipeline
```

- [ ] **Step 3: Semantic query when embeddings are enabled**

Run when `gbrain doctor --json` reports embedding provider ok:

```bash
gbrain query "How should work documents be processed?"
```

Expected output references:

```text
Document Intake Pipeline
```

If embeddings are disabled, skip this step and record `semantic query pending embedding provider`.

- [ ] **Step 4: Verify graph/edge extraction**

Run:

```bash
gbrain graph-query "projects/example-project" || gbrain links "projects/example-project" || gbrain get "projects/example-project"
```

Expected output includes at least one linked page:

```text
concepts/document-intake-pipeline
```

If this gbrain version exposes a different graph command, run `gbrain --help` and use the available link/graph inspection command. The pass condition is that wikilinks from the project page are visible through gbrain runtime, not only through `rg`.

- [ ] **Step 5: Verify raw/private exclusions**

Run:

```bash
gbrain search "identity-map" || true
gbrain search "basic-design.docx" || true
```

Expected: no private page body is returned. Artifact refs may appear as refs in public pages, but `.artifacts` files themselves must not be indexed as pages.

### Task 8: Create Verification Script for File and Runtime Layers

**Files:**
- Create: `scripts/knowledge/verify-gbrain-work.sh`

- [ ] **Step 1: Create script directory**

Run:

```bash
mkdir -p scripts/knowledge
```

Expected: command exits with status 0.

- [ ] **Step 2: Write verification script**

Create `scripts/knowledge/verify-gbrain-work.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$ROOT_DIR/knowledge/work"

required_files=(
  "$WORK_DIR/gbrain.yml"
  "$WORK_DIR/RESOLVER.md"
  "$WORK_DIR/schema.md"
  "$WORK_DIR/ACCESS_POLICY.md"
  "$WORK_DIR/index.md"
  "$WORK_DIR/projects/example-project/index.md"
  "$WORK_DIR/projects/example-project/meetings/weekly-sync/2026/05/2026-05-26-1030-weekly-sync.md"
  "$WORK_DIR/projects/example-project/worklog/2026/05/2026-05-26/01-basic-design.md"
  "$WORK_DIR/projects/example-project/sources/documents/01-要件定義/example-requirements/index.md"
  "$WORK_DIR/concepts/document-intake-pipeline.md"
)

for file in "${required_files[@]}"; do
  test -f "$file" || { printf 'missing file: %s\n' "$file" >&2; exit 1; }
done

required_dirs=(
  "$WORK_DIR/.raw/projects"
  "$WORK_DIR/.artifacts/projects"
  "$WORK_DIR/.private"
  "$WORK_DIR/_inbox/.raw"
  "$WORK_DIR/projects"
  "$WORK_DIR/people"
  "$WORK_DIR/companies"
  "$WORK_DIR/concepts"
  "$WORK_DIR/source"
)

for dir in "${required_dirs[@]}"; do
  test -d "$dir" || { printf 'missing dir: %s\n' "$dir" >&2; exit 1; }
done

if rg -n '_raw|raw-store|versions/|task_shadow|task-shadow|manifest\.md|\bOrganization\b' "$WORK_DIR"; then
  printf 'deprecated vocabulary found\n' >&2
  exit 1
fi

rg -n '\[\[projects/example-project|\[\[concepts/document-intake-pipeline|raw://work/|artifact://work/' "$WORK_DIR" >/dev/null

if command -v gbrain >/dev/null; then
  gbrain search "Example Project" >/gbrain-work-search-project.txt
  rg -n 'example-project|Example Project' /gbrain-work-search-project.txt >/dev/null

  gbrain search "document intake pipeline" >/gbrain-work-search-concept.txt
  rg -n 'document-intake-pipeline|Document Intake Pipeline' /gbrain-work-search-concept.txt >/dev/null
else
  printf 'gbrain CLI missing\n' >&2
  exit 1
fi

printf 'gbrain work verification passed\n'
```

- [ ] **Step 3: Make script executable**

Run:

```bash
chmod +x scripts/knowledge/verify-gbrain-work.sh
```

Expected: command exits with status 0.

- [ ] **Step 4: Run script**

Run after Task 6 indexing:

```bash
scripts/knowledge/verify-gbrain-work.sh
```

Expected:

```text
gbrain work verification passed
```

### Task 9: Document the GBrain-First Bootstrap

**Files:**
- Modify: `docs/design/knowledge-vault-work.md`

- [ ] **Step 1: Add runtime implementation section**

Add this section before `## Open Decisions`:

```md
## GBrain-First Bootstrap Implementation

work brain は独自 Markdown vault ではなく、gbrain runtime を前提にした source として構築する。

実装順序:

1. upstream gbrain を `gbrain` に clone / refresh する。
2. gbrain CLI を local clone から link する。
3. `gbrain init --pglite` で runtime を初期化する。
4. `gbrain schema use gbrain-recommended` を有効化する。
5. `knowledge/work` を work source として作る。
6. work 固有差分だけを `RESOLVER.md`、`schema.md`、`ACCESS_POLICY.md`、`gbrain.yml` に overlay する。
7. `gbrain import knowledge/work`、`gbrain sync`、必要に応じて `gbrain extract all` を実行する。
8. `gbrain search`、`gbrain query`、graph / link inspection で pages、chunks、links、embedding / keyword retrieval を確認する。

Markdown は system of record、gbrain DB は derived cache として扱う。DB を直接正としない。
```

- [ ] **Step 2: Verify design doc mentions runtime**

Run:

```bash
rg -n 'GBrain-First Bootstrap|gbrain init --pglite|gbrain schema use gbrain-recommended|gbrain import|gbrain sync|derived cache' docs/design/knowledge-vault-work.md
```

Expected output includes all listed phrases.

### Task 10: Final End-to-End Verification

**Files:**
- Verify: `knowledge/work/**`
- Verify: `scripts/knowledge/verify-gbrain-work.sh`
- Verify: `docs/design/knowledge-vault-work.md`

- [ ] **Step 1: File layer verification**

Run:

```bash
fd -t f . knowledge/work | sort
```

Expected output includes:

```text
knowledge/work/RESOLVER.md
knowledge/work/schema.md
knowledge/work/ACCESS_POLICY.md
knowledge/work/gbrain.yml
knowledge/work/projects/example-project/index.md
knowledge/work/concepts/document-intake-pipeline.md
```

- [ ] **Step 2: Runtime import/sync**

Run:

```bash
gbrain import "$(pwd)/knowledge/work"
gbrain sync --no-pull || gbrain sync
```

Expected: both commands exit with status 0. If an embedding error occurs, fix the local `native-ruri` provider or dimension setting before continuing.

- [ ] **Step 3: Runtime verification script**

Run:

```bash
scripts/knowledge/verify-gbrain-work.sh
```

Expected:

```text
gbrain work verification passed
```

- [ ] **Step 4: Semantic query verification when embeddings are enabled**

Run when embedding provider is configured:

```bash
gbrain query "How should work raw documents be handled?"
```

Expected output references `Document Intake Pipeline` or `Example Requirements`.

- [ ] **Step 5: Graph edge verification**

Run available graph command:

```bash
gbrain graph-query "projects/example-project" || gbrain links "projects/example-project" || gbrain get "projects/example-project"
```

Expected output references:

```text
concepts/document-intake-pipeline
```

- [ ] **Step 6: Open key pages with mo**

Run:

```bash
mo knowledge/work/index.md knowledge/work/RESOLVER.md knowledge/work/schema.md knowledge/work/projects/example-project/index.md knowledge/work/concepts/document-intake-pipeline.md
```

Expected output includes:

```text
mo: added
```

## Self-Review

Spec coverage:

- gbrain clone first: Task 1.
- gbrain existing runtime and knowledge structure retained: Tasks 1, 3, 4, 6, 7.
- recommended schema retained: Task 3 and Task 4.
- work-specific trimming / overlay only: Task 4.
- `.raw`, `.artifacts`, `.private`: Task 4 and Task 8.
- project-local meeting/worklog/source/concept PoC: Task 5.
- embedding and semantic query: Task 3, Task 7, Task 10.
- relation / edge verification: Task 7 and Task 10.
- gbrain DB as derived cache: Task 1 and Task 9.

Placeholder scan:

- No deferred-implementation marker or undefined file path remains.

Type consistency:

- Work overlay page types are `worklog_task` and `processed_source`.
- Internal brain links use wikilinks.
- Sidecar references use `raw://work/...` and `artifact://work/...`.
