# 秘書 Agent システム構想

作成日: 2026-05-24
状態: 構想メモ

## 背景

ユーザー自身を「社長」、Agent を「秘書」と見立て、ユーザーに入ってくる仕事を可能な限り Agent が前捌き・代行・整理する仕組みを作る。

目的は、単にタスクを自動化することではない。ユーザーの仕事、判断材料、プロジェクト状況、ナレッジ、日々の流れを Agent が理解できる形に整え、ユーザーは最終判断や重要な意思決定に集中できる状態を作る。

## 目指す姿

- ユーザーに渡されたタスクは、まず秘書 Agent が受け取る。
- Agent はタスクの背景、関係プロジェクト、期限、必要な情報、使用ツール、過去の経緯を確認する。
- Agent は実行可能な作業を代行し、判断が必要なものだけをユーザーに返す。
- 仕事の進捗、ナレッジ、意思決定、TODO は、人間にも Agent にも読める raw データとして保存する。
- Claude、Codex などの既存 Agent ハーネスに乗り、固有実装への依存を小さくする。
- Agent Skills を使い、仕事を「会話」ではなく「再実行可能なプロセス」として扱う。

## 基本方針

### 1. 可能な限り決定論的にする

LLM に毎回自由判断させるのではなく、以下を明示的な設定・ファイル・手順として持つ。

- プロジェクト一覧
- プロジェクトごとの責務、関係者、使用ツール
- タスク分類ルール
- 優先度判断ルール
- 毎日の確認フロー
- ナレッジ保存先
- Agent が勝手に実行してよい操作と、ユーザー確認が必要な操作

LLM は判断の一部に使うが、システムの骨格は Markdown、JSON/YAML、ディレクトリ規約、CLI、既存 API で構成する。

### 2. Raw データを特定ツールに閉じ込めない

ナレッジ管理には gbrain を有力候補とする。ただし、将来別の OSS や仕組みに差し替えられるよう、一次情報はできるだけ Markdown や添付ファイルなどのプレーンな形式で持つ。

gbrain は「検索・グラフ化・Agent 連携のレイヤー」として扱い、raw データそのものは外部から読める形を維持する。

### 3. Agent ハーネスは既存のものを使う

独自の Agent 実行基盤を最初から作り込まない。

想定するハーネス:

- Claude Code
- Codex
- Cursor
- MCP クライアント
- 必要に応じて OpenClaw / Hermes 系

このリポジトリでは、Agent の振る舞い、スキル、ドキュメント、運用ルールを管理する。

### 4. 秘書 Agent は「前捌き」に責任を持つ

Agent の主な価値は、最終決裁ではなく前処理にある。

- 情報収集
- 関連資料の確認
- タスク分解
- 期限・依存関係の整理
- 下書き作成
- 会議前のブリーフィング
- メール・チケット・議事録の要約
- 次アクション候補の提示
- ユーザーが判断すべき論点の抽出

## 必要な棚卸し

### プロジェクト棚卸し

まず、ユーザーが関わるすべての仕事をプロジェクト単位で棚卸しする。

各プロジェクトで整理する項目:

- プロジェクト名
- 目的
- 現在のフェーズ
- ユーザーの責務
- 関係者
- 主要な会議体
- 主要な成果物
- 期限・マイルストーン
- 使用ツール
- Agent に委任できる作業
- Agent がユーザーに確認すべき作業
- 保存すべきナレッジ

### タスク種別の棚卸し

プロジェクト横断で、日常的に発生する仕事の型を洗い出す。

例:

- メール確認
- チャット確認
- Azure DevOps のチケット確認
- GitHub / GitLab / Azure Repos の PR 確認
- 会議前ブリーフィング
- 会議後の議事録整理
- タスク分解
- 技術調査
- 設計レビュー
- 実装レビュー
- ドキュメント作成
- スケジュール調整
- ステークホルダー向け報告
- 個人タスクの整理
- 家庭・プライベートの予定整理

### ツール棚卸し

仕事・個人用途で使っているツールを一覧化する。

想定:

- Azure DevOps
- GitHub / GitLab
- Microsoft Teams
- Slack
- Outlook / Gmail
- Calendar
- Obsidian
- ファイルサーバ
- ローカル開発環境
- 会社 VPN / 社内ネットワーク
- パスワード管理ツール
- CI/CD
- クラウド管理コンソール

各ツールについて、Agent が何を読めるか、何を書けるか、どこから先はユーザー確認が必要かを定義する。

## 一日の流れ

### 朝

Agent が一日の開始前に以下を整理する。

- 今日の予定
- 期限が近いタスク
- 昨日から持ち越した作業
- 未読メール・チャットの重要度分類
- Azure DevOps などのチケット更新
- 会議ごとの事前確認事項
- ユーザーに確認すべき判断事項

出力例:

- 今日必ず見るべきもの
- 代行して進められるもの
- 判断だけ必要なもの
- 後回しでよいもの

### 日中

Agent は入力されたタスクを都度受け取り、以下の流れで前捌きする。

1. どのプロジェクトに属するか判定する。
2. 関連ナレッジを検索する。
3. 必要なツールから状況を取得する。
4. タスクを分解する。
5. Agent が実行できる部分を進める。
6. ユーザー判断が必要な論点だけを提示する。
7. 結果をプロジェクトログや brain に保存する。

### 会議前

Agent が会議前ブリーフィングを作る。

- 会議目的
- 参加者
- 前回までの経緯
- 関連チケット
- 未解決論点
- ユーザーが発言すべきポイント
- 決めるべきこと

### 会議後

Agent が会議後の情報を整理する。

- 決定事項
- 宿題
- 担当者
- 期限
- 更新すべきチケット
- 保存すべきナレッジ
- 次回までに準備すること

### 夕方・終業前

Agent が一日の締めを行う。

- 今日完了したこと
- 未完了のこと
- 明日に送ること
- リスク
- ユーザーが忘れていそうなこと
- brain に保存すべき学び
- 明日の朝に確認すべき項目

## 情報共有と brain の考え方

仕事用ナレッジと個人用ナレッジは、同一ネットワーク内のファイルサーバに集約する方向で考える。

ただし、仕事と個人の情報はアクセス制御・秘匿性・利用可能な Agent を分ける必要がある。

仕事用資料の intake、一次資料、抽出済み Markdown、gbrain 取り込み境界は [ADR-0001: Work 資料の intake と gbrain 取り込み境界](../adr/0001-work-document-intake-and-gbrain-boundary.md) に従う。

仕事用 knowledge vault の全体構成、リンク規約、Agent 書き込み方針は [Work Knowledge Vault Design](../design/knowledge-vault-work.md) に従う。

想定する論理構造:

```text
brain/
  personal/
    ...
  work/
    _inbox/
    .raw/
    .artifacts/
    .private/
    projects/
    people/
    companies/
    meetings/
    decisions/
    concepts/
    source/
    templates/
```

この構造は `work` 側については [Work Knowledge Vault Design](../design/knowledge-vault-work.md) を正とする。`personal` 側は別 brain として後続設計で具体化する。

## ナレッジ管理

### gbrain の位置付け

現時点では gbrain を有力候補とする。

確認時点の gbrain は、Markdown を source of truth とする brain repo、Postgres / PGLite による検索、typed link による知識グラフ、MCP 連携、skillpack を備える Agent memory system として設計されている。

この構想では、gbrain を以下の用途で使う候補とする。

- Markdown ナレッジの検索
- 人・会社・会議・意思決定のリンク化
- Agent からの MCP 経由アクセス
- 日次・夜間の整理処理
- Agent Skills の足場

一方で、gbrain に完全依存しないために以下を守る。

- raw データは Markdown と通常ファイルとして保存する。
- gbrain 固有メタデータは外側に寄せる。
- ディレクトリ構造と命名規則を明文化する。
- 別の検索・メモリ基盤に差し替えられるよう、取り込み口と保存形式を分ける。

参考:

- https://github.com/garrytan/gbrain

### 保存する情報の型

最低限、以下の情報型を定義する。

- Project
- Task
- Meeting
- Decision
- Person
- Company / Team
- Tool
- Document
- Daily Log
- Incident / Risk
- Skill / Process

それぞれに Markdown テンプレートを用意し、Agent が追加・更新できるようにする。

## Agent Skills の使い方

Agent Skills は、個別作業を再現可能なプロセスとして扱うために使う。

初期に必要そうな Skill:

- project-inventory: プロジェクト棚卸し
- tool-inventory: 使用ツール棚卸し
- daily-briefing: 朝のブリーフィング
- daily-closeout: 終業前レビュー
- meeting-briefing: 会議前準備
- meeting-followup: 会議後整理
- task-triage: タスク分類・優先度付け
- ado-triage: Azure DevOps チケット整理
- knowledge-capture: ナレッジ保存
- decision-log: 意思決定記録
- document-draft: ドキュメント下書き
- review-assistant: PR / 設計レビュー補助

Skill は Claude / Codex など特定 Agent だけに閉じず、Markdown ベースの手順として管理する。

## Agent の権限設計

Agent ができることを段階的に分ける。

### Read

- ナレッジを読む
- チケットを読む
- カレンダーを読む
- メール・チャットを読む
- リポジトリを読む

### Draft

- メール返信案を作る
- チケット更新案を作る
- 議事録を作る
- ドキュメントを作る
- PR コメント案を作る

### Write with Approval

- メール送信
- チケット更新
- カレンダー変更
- 外部共有ドキュメント更新
- 社内システムへの投稿

### Autonomous Write

最初は限定する。

- 個人 brain へのメモ追記
- ローカル作業ログの更新
- 下書きファイルの作成
- ユーザーが明示した範囲内のドキュメント更新

## プロジェクトごとの管理

プロジェクトごとに、Agent が読むべき入口ファイルを置く。

仮案:

```text
projects/
  <project-id>/
    README.md
    status.md
    decisions.md
    meetings/
    tasks/
    references/
    agents.md
```

各ファイルの役割:

- README.md: プロジェクトの目的、背景、関係者、リンク集
- status.md: 現在の状態、直近の進捗、リスク
- decisions.md: 意思決定ログ
- meetings/: 会議メモ
- tasks/: タスク分解や作業ログ
- references/: 参照資料
- agents.md: Agent がこのプロジェクトで守るべきルール

## 初期ロードマップ

### Phase 1: 棚卸し

- 現在のプロジェクト一覧を作る。
- タスク種別を洗い出す。
- 使用ツールを洗い出す。
- 一日の実際の流れを記録する。
- Agent に委任できる作業とできない作業を分ける。

### Phase 2: ディレクトリとテンプレート

- brain / projects / skills の初期構造を決める。
- Project / Meeting / Decision / Daily Log のテンプレートを作る。
- 各プロジェクトの入口ファイルを作る。

### Phase 3: 日次運用

- morning briefing を作る。
- daily closeout を作る。
- 会議前後の Skill を作る。
- タスク triage の Skill を作る。

### Phase 4: ツール連携

- Azure DevOps の読み取り連携を検討する。
- カレンダー・メール・チャットの読み取り連携を検討する。
- 書き込み操作は approval 前提で段階導入する。

### Phase 5: gbrain 検証

- 小さな brain repo を作る。
- Markdown raw データを保存する。
- gbrain に取り込む。
- 検索・リンク・MCP 連携を確認する。
- 別メモリ基盤への差し替えポイントを整理する。

## 未決事項

- 仕事用と個人用 brain を物理的に分けるか、論理的に分けるか。
- 会社情報をローカル Agent / 外部 LLM に渡せる範囲。
- Azure DevOps など各ツールの API 権限。
- Agent が自律実行してよい操作範囲。
- ファイルサーバ上の同期・バックアップ・暗号化方式。
- gbrain を常時稼働させるか、必要時だけ起動するか。
- プロジェクト ID とフォルダ命名規則。
- 日次レビューをどの粒度で保存するか。
- Agent Skills をこのリポジトリで管理するか、brain repo 側で管理するか。

## 次にやること

1. 現在進行中のプロジェクトをすべて列挙する。
2. 直近 1 週間の仕事の流れを時系列で記録する。
3. 使用ツールと Agent に許可できる操作を棚卸しする。
4. `projects/<project-id>/README.md` のテンプレートを作る。
5. `daily-briefing` と `daily-closeout` の Skill から作り始める。
6. gbrain の最小検証用 brain repo を用意する。
