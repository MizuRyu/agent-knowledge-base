# Work Brain スキーマ

基本スキーマ: `gbrain-recommended`

## 追加タイプ

- `worklog_task`: 外部 task workspace から `projects/<project>/worklog/...` 配下へ同期された knowledge projection。
- `processed_source`: `projects/<project>/sources/...` 配下に置く抽出済み Markdown 資料。
- `processed_source_extract`: raw 資料から抽出した本文 Markdown。
- `processed_source_view`: `processed_source_extract` から作る人間用 view。

## Source Directory 規約

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

- `overview.md`: source 全体の MOC。raw、extracted、views、関連 project / concept / worklog をリンクする。
- `extracted/<file-stem>/*.md`: raw ファイル単位の抽出結果。分解単位とファイル名は docs-processor に任せる。
- `views/<scope>/yymmdd_<slug>.*`: 人間用 view。`<scope>` は通常 `<file-stem>`、横断 view は `integrated` など自然名にする。
- `views/` の中身には固定構造を設けない。
- `views/*.html` など Markdown 以外の view は、必要に応じて対応する `.md` や `overview.md` からリンクする。

## ページ規約

- Markdown を system of record とする。
- GBrain DB は derived cache とする。
- 内部リンクには `[[path]]` または `[[path|表示名]]` を使う。
- 現在の理解は `<!-- timeline -->` より上に置く。
- timeline は `<!-- timeline -->` より下に置く。
- timeline entry は `- **YYYY-MM-DD** | 情報源 — 要約` 形式にする。
- raw sidecar は `raw_refs` で参照する。
- 生成 artifact は `artifact_refs` で参照する。
- 詳細な docs-processing 結果は `projects/<project>/sources/**/extracted/<file-stem>/` 配下に置く。
- 人間用 view は `projects/<project>/sources/**/views/<scope>/` 配下に置く。
