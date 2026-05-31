# ADR-0002: Task workspace と brain worklog projection の分離

## ステータス

承認

## コンテキスト

仕事用 brain では、タスク対応履歴を将来の Agent が再利用できる knowledge として残したい。

一方で、実際のタスク対応では、ユーザー依頼の原文、todo、試行錯誤、作業中メモ、中間成果物、レビュー差し戻し、再対応ログなどが発生する。これらをすべて brain に直接置くと、brain が operational state と durable knowledge の混在場所になり、検索・graph・再利用知識の品質が落ちやすい。

gbrain の repo architecture では、task / todo / session log のような operational state は agent repo 側、people / companies / meetings / projects / concepts のような world knowledge は brain repo 側に置く考え方がある。Markdown は system of record、DB は derived cache であり、brain に入る情報は cross-link されて将来検索・graph traversal されることを前提にする。

そのため、task の作業場所と brain に残す worklog を同一視しない方針が必要になる。

## 決定

task の実作業場所は brain の外に置く。brain 内の worklog は、task workspace から同期された knowledge projection として扱う。

基本構造は以下とする。

```text
tasks/
  YYYY/MM/YYYY-MM-DD/NN-<task-slug>/
    task.md
    scratch.md
    draft.md
    tmp-output.md

knowledge/work/
  projects/<project>/
    worklog/YYYY/MM/YYYY-MM-DD/NN-<task-slug>.md
    concepts/
    sources/
    meetings/
```

`tasks/.../task.md` は実作業の source of truth とする。

`knowledge/work/projects/<project>/worklog/...` は、task から抽出した整理済み作業知識とする。将来 Agent が検索・query・graph traversal で参照する対象は brain worklog であり、task workspace の雑多なログではない。

task workspace 側の `task.md` には、少なくとも以下を持つ。

```md
# Task

## User Request

ユーザー依頼の原文。

## Status

in_progress / review / done / reopened など。固定 enum ではなく推奨値ベース。

## Referenced Knowledge

- [[projects/foo/overview|Project Foo]]
- [[projects/foo/sources/documents/01-要件定義/example/overview|要件定義]]
- [[projects/foo/meetings/weekly-sync/2026/05/2026-05-29-1030-weekly-sync|会議メモ]]
- [[concepts/document-intake-pipeline|Document Intake Pipeline]]

## External / Raw Inputs

- raw://work/projects/foo/documents/example
- SharePoint: ...

## Outputs

- artifact://work/projects/foo/worklog/...
- knowledge/work/projects/foo/sources/...

## Work Log

- 2026-05-29 10:00 ...
```

brain worklog 側には、少なくとも以下を持つ。

```md
---
type: worklog_task
status: review
project: foo
task_ref: task://local/YYYY/MM/YYYY-MM-DD/NN-task-slug
---

# Task Title

## Summary

何をしたか。

## Referenced Knowledge

- [[projects/foo/overview|Project Foo]]
- [[projects/foo/sources/documents/01-要件定義/example/overview|要件定義]]
- [[concepts/document-intake-pipeline|Document Intake Pipeline]]

## Outputs

- artifact://work/projects/foo/worklog/...

## Reuse Notes

次回似たタスクで使える判断・手順・注意点。

<!-- timeline -->

- **2026-05-29** | Created — 初回対応。
- **2026-05-30** | Reopened — レビュー指摘対応。
```

task と knowledge の relation は二重に保持する。

- `task.md` の `Referenced Knowledge`: この作業で何を参照したかの実行ログ。
- brain worklog の `Referenced Knowledge`: gbrain の graph / search / query で将来辿るための整理済み relation。

task が一度完了した後に reopen された場合は、原則として同じ task workspace と同じ brain worklog を更新する。brain worklog は新しいファイルに分けず、timeline に `reopened`、`review2`、`fixed` などを append する。

同期トリガーは以下のハイブリッドとする。

- task 終了時、review 提出時、重要 checkpoint 時の manual sync。
- 1日1回の daily batch による漏れ・中断・reopen・未同期差分の補正。
- 新しい task 開始時の on-start lookup。これは read-only であり、brain から類似 worklog / concepts / sources を読んで task.md の `Referenced Knowledge` に記録する。

## 理由

task workspace は作業中の状態を保持する場所であり、試行錯誤や中間ファイルを含む。これを brain に直接入れると、gbrain が index する対象が増え、検索結果に作業ノイズが混ざる。

brain worklog は durable knowledge であり、将来の Agent が「似たタスクで何を参照し、何を判断し、何を出力したか」を知るための projection である。作業ログを丸ごと保存するのではなく、再利用に必要な summary、referenced knowledge、outputs、reuse notes、timeline を残すことで、brain の品質を保てる。

gbrain は wikilink と Markdown link から graph edge を作る。task workspace が gbrain index 対象外である場合、task.md の wikilink は graph edge にならない。そのため、将来 graph traversal したい relation は brain worklog にも投影する必要がある。

task 終了時だけ同期する案は、直後の別タスクで最新知識を使える利点があるが、更新忘れや中断タスクが漏れやすい。daily batch だけにする案は運用負荷が低いが、当日中の知識反映が遅れる。そのため、manual sync を主、daily batch を補正係とする。

reopen のたびに別 worklog を作る案もある。しかし、同じタスクに関する履歴が分散し、レビュー差し戻し後に「どのタスクだったか」を辿りにくくなる。既存 task folder を再利用する運用の良さを残すため、reopen は同じ task / worklog に timeline append する。

## 影響

brain 内の `worklog` は「作業場所」ではなく「同期された作業知識」と定義される。

Agent / skill には、task workspace から brain worklog へ同期する処理が必要になる。同期処理では以下を行う。

- task.md の user request / status / work log / outputs / referenced knowledge を読む。
- brain worklog を作成または更新する。
- `Referenced Knowledge` を brain worklog に wikilink として投影する。
- outputs を `artifact://` または Markdown link として記録する。
- 再利用できる知見を `Reuse Notes` に整理する。
- 複数タスクで再利用できる知識は `concepts/` に昇格する。
- reopen / review / fixed などの状態変化を timeline に append する。

task workspace 側のファイルは operational state であり、gbrain の通常 import / extract 対象にしない。必要に応じて別 repo、別 folder、または agent workspace 配下で管理する。

`knowledge/work/projects/<project>/worklog/` は、project page、meeting、processed source、concept と相互リンクする。これにより、次回 task 開始時に gbrain search / query / graph から過去対応と参照知識を辿れる。

今後、`task-creator` 相当の skill は `todo.txt` ではなく `task.md` を作る方向に寄せる。ただし、task workspace の構造や status の表現は最初から過度に固定せず、運用で改善する。
