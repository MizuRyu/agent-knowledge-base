# Document Intake Dedup Design

作成日: 2026-05-31
状態: Review

## 目的

task を進めるために必要な一次資料を work brain へ連携する際、版違い、再ダウンロード、コピー suffix 付きファイルを別資料として蓄積しない。

docs-processing は、raw ファイルを論理資料単位に集約し、最新版の raw 原本と抽出済み Markdown だけを保持する。これにより、人間が辿りやすいフォルダ構造と、ノイズの少ない gbrain retrieval を両立する。

## 前提

- user は未分類の一次資料を `_inbox/` に投入できる。
- docs-processing は user 指示を受けた coding agent / human-in-the-loop が明示実行する。
- raw 原本は `.raw/` に置き、Git と gbrain semantic index の対象外とする。
- docs-processing 済み Markdown は `projects/<project>/sources/` に置く。
- raw を取得した場合は、同じ処理で extracted Markdown を生成する。
- doc-id や version directory を人間向けパスに使わない。

## 採用方針

### 論理資料単位で保存する

raw ファイル名から論理資料名を推定し、論理資料単位のフォルダへ集約する。

入力例:

```text
_inbox/
  基本設計書_v1.xlsx
  基本設計書_v2.xlsx
  基本設計書_v2 (1).xlsx
```

保存先:

```text
.raw/projects/<project>/documents/02-基本設計/
  基本設計書/
    基本設計書_v2.xlsx
    metadata.json

projects/<project>/sources/documents/02-基本設計/
  基本設計書/
    overview.md
    extracted/
      sheet-概要.md
      sheet-画面一覧.md
    metadata.json
```

`基本設計書/` は論理資料名である。raw 原本ファイルは、投入された時点のファイル名を維持する。`original.xlsx` のような共通名へ改名しない。

### 固定カテゴリで表示順を安定させる

カテゴリの番号は資料ごとの連番ではない。表示順を安定させる固定 prefix とする。

```text
01-要件定義/
02-基本設計/
03-詳細設計/
04-チャットメッセージ/
99-その他/
```

必要に応じて `05-テスト/` などを追加する。分類に自信がない場合は、`99-その他/` へ即時確定せず `_inbox/` に残して確認事項を記録する。

### `.support/` を廃止する

`.support/` は使わない。docs-processing 済み全文は、用途が分かる可視フォルダ `extracted/` に保存する。

```text
<論理資料名>/
  overview.md
  extracted/
    *.md
```

- `overview.md`: gbrain search、graph、embedding の対象。現在理解、要約、raw 参照、関連 wikilink を持つ。
- `extracted/*.md`: Agent が詳細確認時に直接読む一次処理済みデータ。Git 管理するが、既定では gbrain semantic index の対象外とする。

visible directory の `extracted/` を gbrain index から除外する local extension が必要になる。除外対象は `projects/<project>/sources/**/extracted/**` に限定し、別用途で同名フォルダが作られた場合まで一律除外しない。

## 重複排除

docs-processing は、以下の順序で既存資料との同一性を判定する。

```text
1. checksum 一致
2. 正規化した論理資料名の一致
3. raw metadata の更新日時、受領日時、version suffix の比較
4. 必要な場合だけ抽出済み内容の類似性比較
5. 判定不能なら user 確認
```

### checksum が一致する場合

同一 raw とみなす。raw 本体と extracted Markdown を重複保存しない。受領履歴だけを `metadata.json` に追記する。

例:

```text
基本設計書_v2.xlsx
基本設計書_v2 (1).xlsx
```

### checksum は異なるが論理資料名が一致する場合

版違い候補とみなす。

- incoming が新しいと判断できる場合: raw 本体を置換し、extracted Markdown と `overview.md` を再生成する。
- incoming が古いと判断できる場合: raw 本体を保存せず、無視した履歴だけを記録する。
- 新旧を判断できない場合: `_inbox/` に残し、user に確認する。

新旧判定では、SharePoint API、ファイル metadata、または取得元が提供する更新日時を最優先する。取得元更新日時がなければ、受領日時と version suffix を補助情報として使う。受領日時が新しいだけで raw 内容を自動置換しない。

### 論理資料名の正規化

拡張子を除去し、末尾に付く典型的な版・コピー suffix だけを除去する。

正規化対象例:

```text
基本設計書_v1.xlsx       -> 基本設計書
基本設計書-v2.xlsx       -> 基本設計書
基本設計書 rev3.xlsx     -> 基本設計書
基本設計書 (1).xlsx      -> 基本設計書
基本設計書 コピー.xlsx   -> 基本設計書
```

本文に含まれる数字や意味のある識別子は除去しない。正規化規則に確信が持てない場合は、別資料として確定せず user に確認する。

## Metadata

`.raw/.../<論理資料名>/metadata.json` は、raw 本体を1ファイルだけ保持しつつ、置換と重複受領の履歴を追跡する。

最小例:

```json
{
  "schema_version": 1,
  "logical_name": "基本設計書",
  "category": "02-基本設計",
  "current_filename": "基本設計書_v2.xlsx",
  "current_checksum": "sha256:...",
  "source_updated_at": "2026-05-30T10:00:00+09:00",
  "received_at": "2026-05-31T16:00:00+09:00",
  "history": [
    {
      "filename": "基本設計書_v1.xlsx",
      "checksum": "sha256:...",
      "received_at": "2026-05-20T09:00:00+09:00",
      "action": "replaced"
    },
    {
      "filename": "基本設計書_v2 (1).xlsx",
      "checksum": "sha256:...",
      "received_at": "2026-05-31T16:05:00+09:00",
      "action": "ignored_duplicate"
    }
  ]
}
```

`history` は metadata の監査ログであり、古い raw 本体のアーカイブではない。最新版以外の raw 本体は残さない。

`projects/.../sources/.../metadata.json` には、gbrain source page から辿るために必要な軽量情報だけを置く。raw 側 metadata の完全複製は避ける。

raw 本体の置換は、incoming raw の抽出、`extracted/*.md` の生成、`overview.md` の更新、metadata 更新内容の生成が成功した後に行う。途中で失敗した場合は、既存 raw と既存 processed Markdown を維持し、incoming raw を `_inbox/` に残して失敗理由を記録する。

## docs-processing Flow

```text
1. _inbox/ から一次資料を受け取る
2. project と固定カテゴリを推定する
3. ファイル名を正規化して論理資料名を推定する
4. checksum と既存 metadata で重複・版違いを判定する
5. 高信頼なら incoming raw から extracted/*.md を生成または再生成する
6. overview.md と metadata.json の更新内容を生成する
7. 生成成功後に .raw/projects/.../<論理資料名>/ の raw 本体を最新版へ置換する
8. processed Markdown、metadata、_inbox/intake-log.md を更新する
9. 判断不能または処理失敗の raw だけ _inbox/ に残し、確認事項を書く
```

## 代替案

### 1. 受領ファイルをすべて保存する

不採用。証跡は強いが、`v1`、`v2`、`(1)` の raw と extracted Markdown が増え続け、検索と人間の探索をノイズ化する。

### 2. ファイル名が完全一致する場合だけ重複排除する

不採用。SharePoint やブラウザ再ダウンロードによる `(1)`、版 suffix 違いを吸収できない。

### 3. 論理資料へ集約し、最新版 raw だけ保持する

採用。人間が辿れる安定パスを維持し、metadata で更新履歴を確認できる。判定不能時だけ user 確認に戻すことで、誤った上書きを避ける。

## 実装対象

次の implementation plan では、以下を変更対象とする。

1. ADR-0001、work brain architecture、vault design、lifecycle memo の規約更新。
2. `.support/` を `extracted/` に移行。
3. `extracted/` を semantic index から除外する gbrain local extension。
4. PoC source、page template、schema、inbox README の更新。
5. verify script と walker regression test の更新。
6. 既存 docs-processing 運用への重複排除ルールの接続。ファイル種別ごとの抽出ロジックは、既存 skill または既存運用の所在を確認してから変更範囲を決める。

## 受け入れ条件

- `.support/` が work brain 規約とサンプルから消えている。
- `extracted/` が人間と Agent から直接参照できる。
- `overview.md` は gbrain semantic retrieval 対象になる。
- `extracted/*.md` は Git 管理されるが gbrain page、chunk、embedding 対象にならない。
- raw 原本は投入時のファイル名を維持する。
- 同一 checksum の raw は重複保存されない。
- 高信頼な版違いは同じ論理資料へ自動統合される。
- 最新版以外の raw 本体は残らず、履歴は metadata に記録される。
- 判定不能な raw は上書きされず inbox に残る。
- 抽出または metadata 更新に失敗した場合、既存 raw と既存 processed Markdown は維持される。
