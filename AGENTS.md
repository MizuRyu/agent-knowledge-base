# Agent Instructions

この repository で `knowledge/work/` を読む・更新する coding agent は、作業前に以下を読むこと。

1. `knowledge/work/ACCESS_POLICY.md`
2. `knowledge/work/RESOLVER.md`
3. `knowledge/work/schema.md`
4. 対象 project の `knowledge/work/projects/<project>/overview.md`

## Work Brain Rules

- Markdown を knowledge の正本とし、gbrain DB は derived cache として扱う。
- raw 原本を `knowledge/work/projects/` 配下に置かない。
- 未処理 raw は `knowledge/work/_inbox/`、処理済み raw は `knowledge/work/.raw/projects/<project>/...` に置く。
- docs-processor の raw 変換結果は `projects/<project>/sources/.../<source-id>/extracted/<file-stem>/*.md` に置く。
- `extracted/<file-stem>/` 配下の分解単位とファイル名は docs-processor の処理形式に任せる。
- 人間用 view は `projects/<project>/sources/.../<source-id>/views/<scope>/yymmdd_<slug>.*` に置く。
- `views/` の中身には固定構造を設けない。必要な形式を自然に置き、gbrain で辿らせたい場合は `.md` からリンクする。
- HTML、画像、Office、PDF などの重い成果物や配布物は、必要に応じて `.artifacts/projects/<project>/...` に置き、Markdown から `artifact://work/...` で参照する。
- `.private` の内容を output、worklog、生成 Markdown、timeline に書かない。

## Project Initialization

新規 project は `scripts/knowledge/init-work-project.sh <project-slug> "<display-name>"` で作成する。

`knowledge/work/templates/pages/*.md.template` は global template であり、initializer が project 配下の `overview.md` や `.templates/meeting.md.template` を生成するために使う。
