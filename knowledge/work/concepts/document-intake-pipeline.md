---
type: concept
status: active
aliases: ["docs-processing", "document intake"]
tags: ["knowledge", "documents"]
---

# 資料取り込みパイプライン

## 現在の状態

仕事の資料は raw 原本、処理済み Markdown、生成 artifact に分ける。raw を取得した場合は、同じ処理フローで抽出済み Markdown を生成する。バージョン違い、再ダウンロード、複製されたファイルは 1 つの論理資料へ集約する。raw 原本は最新版だけを保持し、置換履歴は metadata に記録する。

初期の docs-processing は、人間または coding agent が明示的に実行する。専用の local chat LLM は v1 の初期構築に含めない。

## リンク

- [[projects/example-project/overview|サンプルプロジェクト]]
- [[projects/example-project/sources/documents/01-要件定義/example-requirements/overview|サンプル要件定義]]

<!-- timeline -->

- **2026-05-26** | 初期構築 — 資料取り込みルールを再利用可能な concept に昇格。
