# GBrain Upstream Maintenance

作成日: 2026-05-31
状態: Active

## 目的

`gbrain/` は agent-knowledge-base repository に vendor として取り込む。work brain の runtime と native `ruri-v3` provider を一つの repository で管理しつつ、必要なときだけ OSS 本家の更新を取り込める状態を維持する。

## 現在の基準

- Upstream: `https://github.com/garrytan/gbrain.git`
- Imported revision: `eefe8b57c26fdd18a27d777d3bb9da808ea2762e`
- Imported version: `0.42.1.0`
- Local extension: native `ruri-v3-310m` embedding provider
- Local extension: parent Git repository 配下の source directory を同期対象として扱う scoped sync
- Local extension: full sync でも `README.md`、`index.md`、`schema.md` などの metafile を除外する strict walker
- Local extension: work brain の `gbrain.yml` に基づく scoped source tracking

## 更新方針

毎回最新版へ追従しない。必要な修正や機能がある場合に、専用 branch で upstream を取り込んで検証する。

```bash
git switch -c chore/update-gbrain-upstream
git fetch gbrain-upstream master
git subtree pull --prefix=gbrain gbrain-upstream master --squash
```

衝突時は上記 local extension を維持する。更新後は imported revision と version をこの文書で更新する。

## 必須検証

```bash
cd gbrain
bun test test/ai/ruri-recipe.test.ts
bun run typecheck

cd ..
scripts/knowledge/bootstrap-gbrain-work.sh
scripts/knowledge/verify-gbrain-work.sh
```

`bootstrap-gbrain-work.sh` は derived PGLite DB を削除して再構築する。通常同期には `maintain-gbrain-work.sh` を使う。
