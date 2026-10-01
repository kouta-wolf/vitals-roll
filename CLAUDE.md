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

**コマンドはコンテナ内で実行する。** ホストのRubyは3.2.3（プロジェクトは3.4.9）でgemも入っていないため、`bundle exec rspec` や `bin/rails` はホストでは動かない。

```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
docker compose run --rm web bin/rails console
```

以下はいずれもコンテナ内で実行する前提。

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

# フロントエンド
yarn typecheck             # tsc --noEmit（esbuildは型検査をしないため必須）
yarn test                  # vitest run
yarn build                 # esbuild（本番は RAILS_ENV=production でminify＋React production）
yarn build:css

# Lint / セキュリティ
bin/rubocop                # rubocop-rails-omakase ベース
bin/rubocop -a
bin/brakeman --no-pager
bin/bundler-audit
```

## 技術スタック

Rails 8.1 / Ruby 3.4 / PostgreSQL 17 / Node 22 / Devise（+ devise-i18n, rails-i18n で日本語化）/ Kaminari。

フロントエンドは Hotwire（Turbo + Stimulus）と **React 19 + TypeScript** が併存する。バンドラは esbuild（設定は `esbuild.config.mjs`）、CSSは TailwindCSS 4。Vite は使っていない（`vite` は Vitest のピア依存として入っているだけ）。

- `app/javascript/react/` — Reactコンポーネントとマウント処理
- `app/javascript/domain/` — Reactに依存しない純粋なSW2.5ロジック（型と判定式）

テストは RSpec + FactoryBot + Faker、フロントエンドは Vitest（jsdom）。Capybara・selenium-webdriver はGemfileにあるが `spec/system` は未作成。

## コーディング規約（Rails）

### 生SQLを書かない

`execute` / `find_by_sql` / `exec_query`、および `where("...")` `order("...")` のような文字列条件は使わず、ActiveRecord のクエリメソッドで書く。Railsが備えるプレースホルダのエスケープと識別子のクォートが効かなくなるため。範囲条件は終端のみのRange（`where(level: ..0)` → `level <= 0`、`where(level: ...0)` → `level < 0`）で表現できる。

どうしても必要な場合は、値はプレースホルダ（`where("x > ?", v)`）で渡し、ユーザー入力を `Arel.sql` に通さない。採用理由と代替案をコメントに残す。

### マイグレーションでアプリのモデルを使わない

`default_scope` やバリデーションの追加、リネームで過去のマイグレーションが壊れるため。データの一括更新が必要なら、マイグレーション内に `self.table_name` を指定した専用モデルを定義して `update_all` を使う。

### バリデーションを通らない更新に注意する

`update_all` / `update_column` / `increment!` / `decrement!` / `insert_all` はバリデーションとコールバックを通らない。`update!` を使う箇所と混在させると、「片方の操作だけが `RecordInvalid` で落ちる」という非対称な壊れ方をする。

実例（#168）: `Character#advance_round!` は `increment!` でバリデーションを通らないが、`#reset_round!` は `update!` で全属性を検証する。そのため属性に範囲バリデーションを足すと、範囲外の既存行では「ラウンドを進める」は成功するのに「リセット」だけが500になる。

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

**現在、判定式ロジックは Ruby と TypeScript の両方に存在する。** `app/models/character.rb` が画面で使われている実装で、`app/javascript/domain/formula.ts` は #158 で移植したもの（まだ画面から呼んでいない）。#160 でReact側へ切り替え、Ruby側を削除する。

移植時に揃えた点: Ruby の `Integer#/` は負数を**切り下げる**（`-8 / 6` は `-2`）ため、TS側は `Math.trunc` ではなく `Math.floor` を使う。また `value_kind: ability` のバフは個別ではなく**合計してから**÷6する。

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

PR と `main` への push で `.github/workflows/ci.yml` が4ジョブを実行する: `scan_ruby`（Brakeman + bundler-audit）、`lint`（RuboCop）、`frontend`（`tsc --noEmit` + `vitest run`）、`rspec`（PostgreSQLサービスコンテナ + yarn build / build:css の後に実行）。

本番は Render（Web）+ Neon（PostgreSQL）で、構成は `render.yaml`、手順は `docs/deploy.md`。

- メール送信は Render が SMTP ポートを遮断するため Resend の HTTP API（`config.action_mailer.delivery_method = :resend`）を使う。
- **キャッシュ・ジョブ・Action Cable はDBを使わない構成にしている**（`:memory_store` / `:async` / cable も `async`）。Neon無料プランのcompute枠は月100 CU-hours で、solid_queue や solid_cable のポーリングを動かすと16〜17日で使い切るため。この判断に伴い3つのgemもGemfileから外してある。詳細と注意点は `docs/deploy.md` 参照。
- Render のスピンダウン対策として、Google Apps Script が10分おきにトップページを叩いている。DBに触らないパスなので Neon は寝たままで、これが意図した状態。
