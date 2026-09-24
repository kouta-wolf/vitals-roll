# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ

[kouta-wolf/vitals-roll](https://github.com/kouta-wolf/vitals-roll)

SW2.5（ソード・ワールド2.5）のオンラインセッション中にバフの残りラウンドを管理し、バフ反映済みの判定式をクリップボードへコピーするRailsアプリ。サービスの背景・想定ユーザー・機能スコープは `README.md` に詳しい。

Issue は `#番号` で参照できる（例: #55）。ユーザーが `#番号` で言及した場合は `docs/issues.json` を読む。一覧の最新化は `gh issue list`。

## 開発環境

```bash
docker compose up          # http://localhost:3000（db: postgres:17.9 も同時起動）
bin/dev                    # ローカル直接起動（別途PostgreSQLが必要）
```

`bin/dev` は `Procfile.dev` に従い Rails server / esbuild（`yarn build --watch`）/ TailwindCSS CLI（`yarn build:css --watch`）の3プロセスを起動する。JS・CSSは `app/assets/builds/` へビルドされ、Propshaftが配信する。

DB接続は `DB_HOST` / `DB_USERNAME` / `DB_PASSWORD` の環境変数（`.env.example` 参照）。

開発環境のメールは letter_opener_web で `/letter_opener` から確認する。

## よく使うコマンド

```bash
# DB
bin/rails db:prepare       # 初回セットアップ
bin/rails db:migrate
bin/rails db:seed          # バフプリセット（本番共通）＋ development用テストユーザー

# テスト
bundle exec rspec
bundle exec rspec spec/models/
bundle exec rspec spec/models/character_spec.rb
bundle exec rspec spec/models/character_spec.rb:42   # 行番号指定で単一example

# Lint / セキュリティ
bin/rubocop                # rubocop-rails-omakase ベース
bin/rubocop -a
bin/brakeman --no-pager
bin/bundler-audit
```

## 技術スタック

Rails 8.1 / Ruby 3.4 / PostgreSQL 17 / Hotwire（Turbo + Stimulus）/ esbuild / TailwindCSS 4 / Devise（+ devise-i18n, rails-i18n で日本語化）/ Kaminari。テストは RSpec + FactoryBot + Faker（Capybara・selenium-webdriver はGemfileにあるが `spec/system` は未作成）。

## ドメインモデル

`docs/ER.md` 参照。中心は5テーブル。

| テーブル | 役割 |
|---|---|
| `users` | Devise認証ユーザー |
| `characters` | 基本ステータス6種 + 防護点 + `current_rounds` |
| `weapons` | 武器（威力・クリティカル値・固定値・命中補正） |
| `buff_presets` | アプリ全体で共有するバフの雛形（`character_id` を持たないマスターデータ） |
| `buffs` | キャラクターにかかっているバフの実体（`buff_preset_id` は任意、カスタムバフはnull） |

### 判定式の組み立て（`Character`）

判定式ロジックはすべて `app/models/character.rb` に集約されている。

- `hit_formula(weapon)` → `2d6+<冒険者レベル+DEXボーナス+命中補正>+<DEXバフ合計>`
- `attack_formula(weapon)` → `k<威力>[<クリティカル値>]+<固定値+STR/damageバフ合計><特殊トークン>`

計算上の重要なルール:

- **`value_kind`**: `fixed` はそのまま加算、`ability`（能力値そのものを上げるバフ）は合計を6で割った商（ボーナス換算）を加算する。
- **`special_type`**: 通常の `bonus_value` 加算で表現できない特殊バフ。判定式の末尾へトークンをポン付けする（`critical_ray` → `$+x`、`kubikari` → `r5`、`dice_fix` → `$x`）。integerではなくstring enumで保存しているのは、後から並べ替えてもズレず管理人がDBを直読みして意味が分かるようにするため。
- **`active`**: `false` のバフは判定式から除外される。**新規登録・更新の直後は必ず `active: false`**（`BuffPreset#build_buff_for` / `BuffsController#create_buff_manual` / `#resynced_attrs`）。ユーザーが明示的にトグルするまで判定式が黙って変わらないようにするための仕様。
- **ラウンド進行**: `Character#advance_round!` / `#retreat_round!` / `#reset_round!` が `buffs.remaining_rounds` を増減し、0になると `active: false` に落ちる。`remaining_rounds` が nil のバフは無限持続として増減対象外。

### バフのプリロード規約（壊しやすい箇所）

判定式を描画する経路では、アクション前に `Character#preload_buffs_with_preset!` を必ず呼ぶ（`CharactersController#show/advance_round/retreat_round/reset_round`、`BuffsController#toggle` の `before_action`）。理由:

- `Character` 内のバフ集計（`buff_total_for` / `special_buff_for` / `active_timed_buffs`）は **すべてロード済み `buffs` 配列に対するメモリ内走査**。`where` で取り直すと別インスタンスになり、更新がassociationキャッシュへ反映されず古い値で判定式が組まれる。
- プリロードを忘れるとN+1が復活する（`buff_preset` 参照でバフ件数分のクエリ）。
- `set_character` で取得済みのインスタンスには `includes` が効かないため `ActiveRecord::Associations::Preloader` を使っている。
- `has_many :buffs` の `inverse_of: :character` により `@character.buffs.find(id)` がSQLを投げずプリロード済み配列と同一インスタンスを返す。`BuffsController#toggle` はこれに依存している。

### Turbo Streams

ラウンド進行とバフのトグルは Turbo Stream で部分更新する（`format.turbo_stream` + `format.html` のフォールバック）。更新対象は `dom_id(character, :round)` / `dom_id(character, :buffs_list)` / `dom_id(character, :formula)` / `dom_id(buff)` の4つ。判定式パーシャルは `turbo_frame_tag` で囲まれ、コピーは Stimulus の `clipboard_controller.js` が担当する。

### 認証

`ApplicationController` で全ページ `authenticate_user!`（Deviseコントローラは除外）。公開ページは `TopController#index` と `PagesController`（利用規約・プライバシー・問い合わせ・ガイド）で個別に `skip_before_action` している。キャラクター取得は必ず `current_user.characters.find(...)` 経由。

## CI / デプロイ

PR と `main` への push で `.github/workflows/ci.yml` が3ジョブを実行する: `scan_ruby`（Brakeman + bundler-audit）、`lint`（RuboCop）、`rspec`（PostgreSQLサービスコンテナ + yarn build / build:css の後に実行）。

本番は Render（Web）+ Neon（PostgreSQL）で、構成は `render.yaml`、手順は `docs/deploy.md`。メール送信は Render が SMTP ポートを遮断するため Resend の HTTP API（`config.action_mailer.delivery_method = :resend`）を使う。
