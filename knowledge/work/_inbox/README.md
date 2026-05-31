# Work Inbox

user から受領した未処理ファイルは `_inbox/` 直下に置く。

`_inbox/` の資料ファイルは knowledge ページではない。プロジェクト資料として受け入れる場合は、docs-processing に成功した後で `.raw/projects/<project>/...` 配下へ移動する。処理後は論理資料名ごとに整理し、受領時のファイル名を維持した最新版 raw だけを残す。`projects/<project>/sources/...` 配下には index 対象の `overview.md` を作成し、詳細な docs-processing 結果が必要な場合は可視フォルダ `extracted/` に置く。旧版や重複ファイルの本体は残さず、ファイル名と履歴を raw metadata に記録する。
