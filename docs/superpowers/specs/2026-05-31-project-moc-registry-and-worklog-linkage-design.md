# Project MOC Registry と Worklog Linkage の設計

作成日: 2026-05-31
状態: Draft

## 目的

work brain は project ごとの durable knowledge を `knowledge/work/projects/<project>/` に持つ。

一方で、実作業 task は各 project repository で `task-creator` により作成される想定である。task workspace は operational state であり、gbrain の通常検索対象にはしない。

この設計では、work brain が「どの project がどの repository と task folder に対応するか」を取得する方法を固定する。これにより、後続の `worklog-sync`、`task-creator` 修正、gbrain search 対象整理を同じ前提で進められる。

## 前提

- gbrain core は upstream 追従性を重視し、project/task 運用のためには直接変更しない。
- project の入口は `knowledge/work/projects/<project>/overview.md` とする。別の `MOC.md` は作らない。
- `task-creator` は現在、各 repository の `docs/memo/tasks/<task-dir>/todo.txt` を作る。
- 将来は `todo.txt` ではなく `task.md` に寄せる可能性がある。
- task workspace は gbrain の source of truth ではない。brain に残すのは整理済み `worklog` projection である。
- 外部 LLM API 呼び出しはこの設計の対象外であり、必要な LLM 的処理は別途 Codex CLI job として扱う。

## 採用方針

### Project MOC を source of truth にする

project と repository / task folder の対応は、project MOC である `overview.md` の frontmatter に置く。

例:

```yaml
---
type: project
status: active
aliases: []
tags: []
repos:
  - id: sample-repo
    role: primary
    path: /path/to/sample-repo
    task_root: docs/memo/tasks
    task_file: todo.txt
    task_format: task-creator-v1
worklog_root: worklog
---
```

`repos[].id` は brain 内で使う安定識別子である。

`repos[].path` は local workspace 上の repository path である。work brain は local-first repository なので、初期は絶対 path を許容する。ただし、`task_ref` や worklog には絶対 path を直接書かない。

`repos[].task_root` は repository root からの相対 path とする。

`repos[].task_file` は task directory 内の主ファイル名である。現在の `task-creator` では `todo.txt`、将来の v2 では `task.md` を想定する。

`repos[].task_format` は互換判定用の軽い marker とする。初期値は `task-creator-v1` とし、将来 `task-creator-v2` を追加できるようにする。

`worklog_root` は project directory からの相対 path とする。通常は `worklog` である。

### Registry は派生 cache にする

script が毎回 Markdown frontmatter を横断 parse しなくて済むように、必要なら local runtime cache として registry を生成する。

```text
.gbrain-work/project-registry.json
```

この registry は `overview.md` から生成される derived cache であり、正本ではない。

registry の例:

```json
{
  "generated_at": "2026-05-31T00:00:00+09:00",
  "projects": [
    {
      "project": "example-project",
      "moc": "knowledge/work/projects/example-project/overview.md",
      "worklog_root": "knowledge/work/projects/example-project/worklog",
      "repos": [
        {
          "id": "sample-repo",
          "role": "primary",
          "path": "/path/to/sample-repo",
          "task_root": "docs/memo/tasks",
          "task_file": "todo.txt",
          "task_format": "task-creator-v1"
        }
      ]
    }
  ]
}
```

registry は機械処理の入口であり、人間が編集する場所ではない。手で直す必要がある場合は `overview.md` を直して再生成する。

### task_ref は repo id と相対 path で表す

brain worklog には絶対 path を書かない。

task への参照は以下の形式にする。

```text
task://repo/<repo-id>/<task-root-relative-task-dir>
```

例:

```text
task://repo/sample-repo/260531-01-gbrain-worklog-sync
```

`task_ref` から実ファイルへ解決する処理は registry を使う。

### worklog-sync は MOC/registry を読む

`worklog-sync` は以下の流れにする。

```text
project overview.md
  -> repos[].path / task_root / task_file を読む
  -> task directory を scan
  -> task の status / summary / outputs / referenced knowledge を読む
  -> knowledge/work/projects/<project>/worklog/... に projection を作成または更新
  -> task_ref を frontmatter に残す
```

`worklog-sync` は task workspace を gbrain に取り込む処理ではない。再利用可能な要約、参照 Knowledge、成果物、判断、timeline だけを worklog に投影する。

### extracted Markdown は検索対象に含める

`projects/<project>/sources/**/extracted/*.md` は docs-processing 済みの Markdown であり、raw 原本ではない。

そのため、work brain では `extracted/` Markdown を gbrain search / embedding 対象に含める。

除外するのは以下に限る。

- `.raw/`
- `.artifacts/`
- `.private/`
- `_inbox/` の未処理 raw
- task workspace
- `.templates/`

既存の設計文書にある「`extracted/` は retrieval 対象にしない」という記述は、この方針に合わせて後続で修正する。

## 比較した案

### 案 A: Project MOC のみ

`overview.md` frontmatter だけを正とし、script は毎回これを読む。

利点:

- 編集箇所が少ない。
- 人間が読みやすい。
- brain の project context と運用 metadata が同じ場所にある。

欠点:

- script 側で frontmatter parse と project 横断 scan が毎回必要になる。
- path 解決や重複検出が遅くなる可能性がある。

### 案 B: Central registry のみ

`project-registry.json` だけを正とする。

利点:

- script から読みやすい。
- schema validation しやすい。

欠点:

- project MOC と分離し、二重管理になる。
- 人間が project page を見ても task folder の場所が分からない。
- gbrain search / graph 上の project context と運用 metadata が離れる。

### 案 C: MOC を正、registry は派生 cache

`overview.md` を source of truth とし、必要に応じて `.gbrain-work/project-registry.json` を生成する。

利点:

- 人間向け context と script 向け context の両方を満たせる。
- 二重管理を避けられる。
- upstream gbrain とは独立して実装できる。
- registry が壊れても Markdown から再生成できる。

欠点:

- registry generator が必要になる。
- frontmatter schema の検証が必要になる。

採用案は C とする。

## Error Handling

`overview.md` の `repos` が空の場合、その project は task/worklog sync の対象外として扱う。

`repos[].path` が存在しない場合、registry generation または sync は warning を出し、その repo の task sync を skip する。

`repos[].task_root` が存在しない場合も warning とし、project MOC 自体は invalid にしない。task-creator 未導入 project を許容するためである。

同じ `repos[].id` が複数 project に出る場合は warning とする。ただし、同じ repository を複数 brain project から参照する運用があり得るため、初期は hard error にしない。

同じ project 内で `role: primary` が複数ある場合は error とする。

`task_ref` から実ファイルへ解決できない場合、worklog は削除しない。timeline に解決不能を追記するか、sync report に unresolved として出す。

## 変更対象

この設計を実装する場合の最小変更対象は以下である。

- `knowledge/work/templates/pages/project.md.template`
  - `repos`、`worklog_root` の frontmatter placeholder を追加する。
- `scripts/knowledge/init-work-project.sh`
  - 新規 project の `overview.md` に `repos: []` と `worklog_root: worklog` を出す。
  - 後続で `--repo-path`、`--task-root`、`--task-file` を受け取れるようにする。
- `knowledge/work/schema.md`
  - project frontmatter の運用 metadata と `extracted/` 検索対象方針を記載する。
- `docs/adr/0002-task-workspace-and-brain-worklog-projection.md`
  - task folder discovery は project MOC / registry から行うと追記する。
- `docs/design/work-gbrain-architecture.md`
  - `extracted/` Markdown を retrieval 対象に含めるよう修正する。
- `scripts/knowledge/build-project-registry.*`
  - MOC frontmatter から `.gbrain-work/project-registry.json` を生成する。
- `scripts/knowledge/worklog-sync.*`
  - registry を読み、task から brain worklog を生成または更新する。
- `task-creator` skill
  - 将来、repository task folder の作成形式と `task.md` 移行を反映する。

## 非対象

以下はこの spec では実装しない。

- gbrain core の変更
- Codex CLI job runner
- hosted LLM API の完全遮断実装
- docs-processing skill の変更
- task-creator skill の即時修正
- worklog-sync の実装
- project MOC への実 project path 一括登録

## 検証

実装時は以下を確認する。

- project initializer が `repos: []` と `worklog_root: worklog` を生成する。
- 既存 example project の `overview.md` が新しい frontmatter schema と矛盾しない。
- registry generator が project MOC を読み、期待する JSON を生成する。
- `repos[].path` が存在しない project で sync が失敗終了せず warning になる。
- `role: primary` が複数ある場合に検出できる。
- `task_ref` が絶対 path を含まない。
- `projects/**/sources/**/extracted/*.md` が gbrain search / embedding 対象から除外されない。
- `.raw/`、`.artifacts/`、`.private/`、`_inbox/`、`.templates/` が通常 retrieval に混入しない。
