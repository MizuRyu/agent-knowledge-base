# Work Brain 保存先ルール

この resolver は `gbrain-recommended` を拡張する。最初に upstream gbrain の保存先ルールを使い、その後で以下の work 固有ルールを適用する。

## Work 固有の保存先

1. 非公開の個人対応表、実名、関係性マップ、優先度判断材料 -> `.private/`
2. user から受領した未処理 raw ファイル -> `_inbox/`
3. 処理済み raw 原本 -> `.raw/projects/<project>/...`
4. 生成したリッチ成果物 -> `.artifacts/projects/<project>/...`
5. プロジェクト固有の working knowledge -> `projects/<project>/...`
6. 役割ベースの人物ページ -> `people/<role-id>.md`
7. 会社、部署、チーム -> `companies/<slug>.md`
8. 再利用可能なパターンと task から得た知見 -> `concepts/<slug>.md`
9. 複数プロジェクトで共有する処理済み資料 -> `source/<slug>.md`

## Project Source Layout

project 固有の資料は `projects/<project>/sources/documents/<category>/<source-id>/` に置く。

```text
projects/<project>/sources/documents/<category>/<source-id>/
  overview.md
  extracted/
    <file-stem>/
      *.md
  views/
    <scope>/
      yymmdd_<slug>.*
```

- `overview.md` は source 全体の入口、現在の理解、raw / extracted / views へのリンクを持つ。
- `extracted/<file-stem>/*.md` は docs-processor が raw ファイルから機械的に抽出した Markdown を置く。
- `extracted/` の分解単位とファイル名は docs-processor の形式別処理に任せる。
- `views/<scope>/yymmdd_<slug>.*` は人間用 view を置く。`<scope>` は通常 `<file-stem>`、横断 view は `integrated` など自然名にする。
- `views/` の中身には固定構造を設けない。HTML なども置いてよいが、gbrain で辿らせたい場合は Markdown からリンクする。
- raw 原本は `.raw/projects/<project>/documents/<category>/<source-id>/...` に置き、`projects/` 配下には置かない。

## 必須制約

- 公開 brain ページに実名を書かない。
- `.private` の内容を output、worklog、生成 Markdown、timeline に書かない。
- raw 原本を `projects/` 配下に置かない。
- raw を取得した場合は、対応する extracted Markdown を同時に作る。
- brain ページ間の参照には wikilink を使う。
- sidecar の参照には `raw://work/...` と `artifact://work/...` を使う。
