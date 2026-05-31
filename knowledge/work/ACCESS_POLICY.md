# Work Brain アクセスポリシー

## 既定ルール

- 外部 LLM の利用は既定で禁止する。
- work brain の内容は、既定では外部 LLM に送信しない。
- `.raw` と `.private` は外部 LLM に送信してはならない。
- 承認済みの coding-agent 環境は、ローカル処理のために work brain のファイルを読み取ってよい。
- 外部 issue、SharePoint、Teams、メールへの書き込みには、user の明示的な承認が必要である。

## 個人情報

- 公開 brain ページでは、`dev-a`、`po-a`、`sm-a`、`client-po-a` などの役割ベースの仮名を使う。
- 実名との対応表は `.private/` にだけ置く。
- `.private` の内容を output、推論ログ、worklog、生成 Markdown、公開 timeline に含めてはならない。
