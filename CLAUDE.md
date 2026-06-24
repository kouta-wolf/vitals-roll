# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 開発環境の起動

Docker を使った開発環境:

```bash
docker compose up
```

アクセス: http://localhost:3000

ローカルで直接起動する場合（PostgreSQL が別途必要）:

```bash
bin/dev
```

`bin/dev` は `Procfile.dev` に基づき、Railsサーバー・esbuild（JS）・TailwindCSS（CSS）の3プロセスを同時起動する。

## よく使うコマンド

```bash
# DB操作
bin/rails db:prepare       # DB作成＋マイグレーション（初回セットアップ）
bin/rails db:migrate
bin/rails db:seed

# テスト
bin/rails test                          # 全テスト
bin/rails test test/models/user_test.rb # 単一ファイル
bin/rails test:system                   # システムテスト（Capybara + Selenium）

# Lint / セキュリティ
bin/rubocop                # コードスタイル検査
bin/rubocop -a             # 自動修正
bin/brakeman --no-pager    # Railsセキュリティ静的解析
bin/bundler-audit          # Gemの既知脆弱性チェック
```

## アーキテクチャ概要

### 技術スタック

- **Rails 8.1.3** / Ruby 3.4.x
- **フロントエンド**: Hotwire（Turbo + Stimulus）、esbuild（JSバンドル）、TailwindCSS 4.3.1
- **DB**: PostgreSQL 17.9
- **認証**: Devise（予定）
- **テスト**: Rails標準（Minitest）+ Capybara + Selenium

RuboCop は `rubocop-rails-omakase` をベースにしている（`.rubocop.yml` 参照）。

### ドメインモデル

このアプリの中心的なデータモデル（`docs/ER.md` 参照）:

| テーブル | 役割 |
|---|---|
| `users` | Devise 認証ユーザー |
| `characters` | SW2.5キャラクター。基本ステータス6種 + 防護点 + `current_rounds`を保持 |
| `weapons` | キャラクター所有の武器（威力・クリティカル値・固定値・命中補正） |
| `buff_presets` | アプリ全体で共有するバフの雛形。`character_id`を持たない |
| `buffs` | キャラクターに実際にかかっているバフの実体。`buff_preset_id`は任意（カスタムバフはnull） |

重要な設計上の注意:

- **`buff_presets` と `buffs` の分離**: `buff_presets` はグローバルなマスターデータ。`buffs` はキャラクター毎のインスタンスで、`active`（オン/オフ）と `remaining_rounds`（残ラウンド数）を独自に持つ。
- **`current_rounds`**: 現在は `characters` テーブルに持たせているが、将来の複数人セッション機能追加時に `sessions` テーブルへ移行予定。
- **`special_type`**: 通常の `bonus_value` では表現できない特殊処理（クリティカル値変更・ダイス目固定など）を文字列enumで区別するカラム。判定式組み立てロジックで参照する。
- **`active`**: バフのオン/オフを切り替えて一時的に無効化する。`false` のバフは判定式の計算から除外される。

### アプリケーションの主要機能（MVP）

1. キャラクターのCRUD
2. バフの登録（プリセット選択 or 手動登録）・オン/オフ切り替え
3. ラウンド進行 → `buffs.remaining_rounds` の自動減算、0になると自動オフ
4. バフ反映済み判定式（SW2.5形式: `k30(威力)[クリティカル値]+固定値+バフ合計`）のクリップボードコピー

Turbo Streams によるラウンド進行・バフ状態のリアルタイム更新が実装の核となる。

### CI（GitHub Actions）

PRおよび`main`へのpushで以下が自動実行される（`.github/workflows/ci.yml`）:

1. `scan_ruby`: Brakeman + bundler-audit
2. `lint`: RuboCop
3. `test`: Minitest（PostgreSQL サービスコンテナあり）
4. `system-test`: Capybara（失敗時スクリーンショットをアーティファクト保存）
