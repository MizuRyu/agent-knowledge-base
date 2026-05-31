# ADR-0001: Work 資料の intake と gbrain 取り込み境界

## ステータス

承認

## コンテキスト

仕事用 brain では、会議メモや意思決定だけでなく、SharePoint リンク、Excel、Word、PowerPoint、チャットログなどの一次資料も扱う必要がある。

一方で、Office ファイルなどの複雑な資料をそのまま gbrain に取り込むと、検索・リンク化・要約の品質が不安定になり、資料が増えたときに brain 全体がノイズ化しやすい。また、ユーザーに細かい分類や保存先判断を求めると、運用負荷が高くなり継続しづらい。

そのため、ユーザーは資料を雑に投入でき、Agent が分類・抽出・整理する前提の構造が必要になる。

## 決定

仕事用 brain に root `_inbox/` を設け、ユーザーが分類せずに一次資料を投入できるようにする。

Agent は `_inbox/` 直下に置かれた資料、または SharePoint などから必要に応じて取得した資料を処理し、関連プロジェクトを推定したうえで、原本、加工済み Markdown、生成成果物を別レイヤーに分けて保存する。

プロジェクト配下の `sources/documents` には加工済み情報だけを置く。Office ファイルなどの raw 原本は `projects` 配下に置かず、別レイヤーの `.raw/projects` に保存する。

raw は闇雲に収集・処理しない。必要になったときに必要な raw だけを取得する。raw を取得した場合は、必ず対応する extracted Markdown を生成し、`projects/<project-name>/sources` から参照できる状態にする。

保存先のパスは doc-id ではなく、人間が辿れる論理資料名・カテゴリ名を使う。内部 ID や raw 参照は frontmatter または `metadata.json` に保持する。

版違い、再ダウンロード、コピー suffix 付きファイルは、別資料として増やさず同じ論理資料へ集約する。raw 本体は最新版だけを投入時のファイル名のまま保持し、古い raw 本体や重複 raw 本体は残さない。置換、重複受領、無視した旧版の履歴は `metadata.json` に記録する。

基本構造は以下とする。

```text
brain/
  work/
    _inbox/
      intake-log.md

    .raw/
      projects/
        <project-name>/
          <論理資料名>/
            <投入時ファイル名>.xlsx
            metadata.json

    .artifacts/
      projects/
        <project-name>/
          <成果物名>/
            output.docx
            metadata.json

    projects/
      <project-name>/
        README.md
        status.md
        meetings/
        decisions.md

        sources/
          documents/
            01-要件定義/
              <論理資料名>/
                overview.md
                extracted/
                  <file-stem>/
                    *.md
                views/
                  <scope>/
                    yymmdd_<slug>.*
                metadata.json
            02-基本設計/
            03-詳細設計/
            04-チャットメッセージ/
            99-その他/
```

各層の責務は以下とする。

- `_inbox/`: ユーザーが雑に置く未処理 raw。未処理の資料だけを置く。
- `_inbox/intake-log.md`: Agent による intake 処理ログ、分類不能理由、移動先、抽出結果の記録。
- `.raw/projects`: 原本の証跡・再抽出用アーカイブ。論理資料ごとに最新版だけを保持し、原則として Agent は原本内容を変更しない。
- `.artifacts/projects`: Agent が生成した Word、Excel、PowerPoint、PDF、画像、zip などのリッチ成果物。Markdown source から派生した delivery artifact として扱う。
- `projects/<project-name>/sources`: 抽出済み・要約済み・リンク済みの軽量 knowledge。各リポジトリから symlink して参照できることを優先する。
- `overview.md`: gbrain が読む source page。資料の現在理解、参照先、関連リンクを置く。
- `extracted/<file-stem>/*.md`: raw ファイル単位の一次処理済みデータ。分解単位とファイル名は docs-processor の形式別処理に任せる。
- `views/<scope>/yymmdd_<slug>.*`: 人間用 view。`<scope>` は通常 `<file-stem>`、横断 view は `integrated` など自然名にする。中身には固定構造を設けない。
- `metadata.json`: 元ファイル名、入手日、関連プロジェクト、分類、処理状態、内部 ID、raw / artifact 参照、チェックサムなどの Agent 向けメタデータ。

`overview.md` だけで十分な軽い資料では、`views/` を無理に作らない。Office ファイルなど抽出結果が大きい資料は `extracted/<file-stem>/` を追加し、人間用の見方が必要な場合だけ `views/<scope>/` を追加する。

gbrain に取り込む主対象は `projects/<project-name>/sources` 配下の加工済み Markdown とする。`.raw/projects` は証跡・原本管理の対象であり、原則として gbrain の検索・知識グラフ化の主対象にはしない。

Agent は保存先を自動分類する。ただし、信頼度が低い場合や新カテゴリが必要な場合は、勝手に確定せず `_inbox/` に資料を残し、`_inbox/intake-log.md` に確認事項を書く。

## 理由

doc-id 主体のフォルダ設計は Agent には扱いやすいが、ユーザーが資料の場所を直感的に辿りにくい。仕事では、人間がプロジェクトフォルダから「要件定義」「基本設計」「議事録」などの意味単位で資料を探す場面が多いため、パスは人間向けにする。

一方で、重複検出、処理状態管理、参照関係管理には機械向け ID やメタデータが必要になる。そのため、内部 ID はフォルダ名ではなく frontmatter または `metadata.json` に保持する。

gbrain は Markdown を中心に検索・リンク化・Agent 連携するレイヤーとして扱う。Office ファイルや SharePoint 由来の資料を直接 brain 化するのではなく、まず `extracted/*.md` で Agent が読める状態に正規化し、`overview.md` に検索対象とする現在理解を置くことで、取り込み品質と後続処理の安定性を上げる。

各プロジェクトの `sources` は、必要なリポジトリから symlink して参照できる軽量な working knowledge layer とする。そのため、重い Office ファイルや原本アーカイブを `projects` 配下に置かない。

raw 原本は一度抽出すれば普段は参照しないことが多い。原本まで Git 管理しようとするとリポジトリが重くなり、同期や履歴管理が扱いづらくなる。そのため、原本は `.raw/projects` に保存し、通常の Git 管理対象から外す。パス上に version フォルダや timestamp prefix は持たない。同じ論理資料の旧版本体は削除し、履歴は `metadata.json` に残す。必要になれば取得元 SharePoint、ファイルサーバ、または将来の外部 blob 管理から再取得する。

重複・版違い判定は、checksum 一致、正規化した論理資料名、取得元更新日時、version suffix、必要時の抽出内容類似性の順で行う。高信頼な重複と版違いは Agent が自動統合する。新旧や同一性を判断できない場合は `_inbox/` に残して user に確認する。

生成した Word / Excel / PowerPoint / PDF も Markdown source ではなく派生成果物であるため、`.artifacts/projects` に置く。プロジェクト配下には、成果物そのものではなく、成果物への `artifact_ref` と生成元 Markdown へのリンクを残す。

代替案として、すべての資料を `sources/documents/<doc-id>` に集約する案もある。しかし、ユーザーの探索性が下がり、保存場所の意味が `metadata.json` を読まないと分からなくなるため採用しない。

また、プロジェクト配下の `sources` に raw 原本まで含める案もある。しかし、symlink 参照するプロジェクトフォルダが重くなり、各リポジトリで扱いづらくなるため採用しない。

プロジェクト外のグローバル `sources` にすべて集約する案もある。しかし、当面は仕事資料の多くが特定プロジェクトに紐づく想定であり、プロジェクトごとの文脈から辿れることを優先する。複数プロジェクトで共有する資料が増えた場合は、共有 source 領域またはリンク参照で拡張する。

## 影響

ユーザーは資料を分類して保存する必要がなくなり、まず `_inbox/` に置くだけでよくなる。

Agent 側には、以下の docs-processing フローが必要になる。

- `_inbox/` の新規資料検出
- 必要な raw のオンデマンド取得
- ファイル種別判定
- 関連プロジェクト推定
- 資料カテゴリ推定
- `.raw/projects` への raw 原本配置
- checksum と raw 参照の記録
- `projects/<project-name>/sources` への保存先フォルダ作成
- checksum、論理資料名、取得元更新日時による重複・版違い判定
- `extracted/<file-stem>/*.md` への Markdown 化
- `views/<scope>/yymmdd_<slug>.*` への人間用 view 作成
- `overview.md` / `metadata.json` 作成・更新
- `_inbox/intake-log.md` への処理ログ出力
- 判定不能時は `_inbox/` に残して確認事項を記録

プロジェクトごとに資料カテゴリを調整できるよう、将来的には `classification.yml` のような分類ルールファイルを置く余地を残す。

この決定により、brain の原本管理、gbrain の知識化対象、delivery artifact が分離される。資料の原本管理は `.raw/projects`、派生成果物は `.artifacts/projects` で行い、プロジェクト配下には処理済み Markdown と参照情報を中心に置く。版違い資料は論理資料単位で集約し、raw 本体と semantic retrieval のノイズを増やさない。

raw を取得する操作は、必ず extracted Markdown の生成とセットで扱う。raw だけを取得して未処理のまま放置することは原則として避ける。
