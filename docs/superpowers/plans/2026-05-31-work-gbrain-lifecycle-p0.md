# Work GBrain Lifecycle P0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the work brain follow gbrain's minimum Git-backed lifecycle while keeping raw files, generated artifacts, and verbose extraction support files outside semantic retrieval.

**Architecture:** The repository root owns docs, scripts, the vendored gbrain runtime, and the Markdown work vault. Only `knowledge/work/` is registered as the gbrain source. Canonical brain pages use syncable filenames and structured timelines; hidden sidecars stay readable from disk but are skipped by gbrain walkers.

**Tech Stack:** Git, Bash, gbrain CLI, Bun, PGLite, Markdown, local ruri-v3 embeddings.

---

### Task 1: Vendor Runtime and Repository Boundary

- [ ] Initialize the repository root as Git.
- [ ] Update `gbrain/` to the fetched upstream revision and reapply native ruri changes.
- [ ] Remove nested `gbrain/.git/` metadata and the obsolete `tmp/` investigation clone.
- [ ] Record the upstream remote and maintenance procedure.

### Task 2: Make Brain Pages Syncable

- [ ] Rename entity `index.md` files to `overview.md`.
- [ ] Move verbose document extraction under visible `extracted/`.
- [ ] Convert brain page timelines to `<!-- timeline -->` and structured entries.
- [ ] Add page templates using the canonical timeline format.

### Task 3: Align Configuration and Scripts

- [ ] Replace the ineffective top-level `db_only` configuration with `storage.db_tracked`.
- [ ] Keep sidecar exclusions in repository and work-vault `.gitignore` files.
- [ ] Keep bootstrap destructive and explicit.
- [ ] Add a non-destructive maintenance wrapper for normal committed Markdown updates.

### Task 4: Verify Lifecycle

- [ ] Verify the local ruri provider and TypeScript types.
- [ ] Rebuild the derived PGLite database from committed Markdown.
- [ ] Verify sync, extraction, stale embedding refresh, graph traversal, timeline rows, storage status, and `extracted/` exclusion.
