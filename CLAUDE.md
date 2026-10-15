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

- `app/javascript/react/` — Reactコンポーネント、マウント処理、保存フック
- `app/javascript/domain/` — Reactに依存しない純粋なSW2.5ロジック（型・判定式・reducer）

**役割分担**: キャラクター詳細ページの戦闘操作はReact、それ以外（一覧・CRUDフォーム・Devise・静的ページ）はERB + Turbo。詳細は「戦闘操作はReactが持つ」を参照。

テストは RSpec + FactoryBot + Faker、フロントエンドは Vitest（jsdom）+ @testing-library/react。Capybara・selenium-webdriver はGemfileにあるが `spec/system` は未作成。

Vitest は `globals: false` のため **testing-library の自動クリーンアップが働かない**。コンポーネントやフックのテストでは `afterEach` で `cleanup()` を呼ぶこと（忘れるとイベントリスナが前のテストから残る）。

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

### 戦闘操作はReactが持つ（#160）

キャラクター詳細ページの**ラウンド進行・バフのオン/オフ・判定式の表示とコピー・武器の選択はReactが担当する**。サーバ側の責務は初期データを埋め込むことと、状態を保存することだけ。

| 層 | 役割 |
|---|---|
| `app/javascript/domain/formula.ts` | 判定式の算出（純粋関数） |
| `app/javascript/domain/combatState.ts` | 状態と `useReducer` のreducer、保存用スナップショットへの変換 |
| `app/javascript/react/CombatPanel.tsx` | ルート。reducerと保存フックを束ね、各パネルへPortalで差し込む |
| `app/javascript/react/useCombatStateSave.ts` | デバウンス保存（2秒 / 最大15秒）と離脱時フラッシュ |
| `app/helpers/combat_states_helper.rb` | 初期データのシリアライズ |
| `CombatStatesController` | 保存先。スナップショットを受けて冪等に更新（#159） |

重要な点:

- **判定式とラウンド操作のロジックはTypeScript側が単一の正。** Ruby側の `Character#hit_formula` / `#advance_round!` 等は #160 で削除した。移植時に Ruby の実挙動と突き合わせており、`value_kind: ability` の換算は**合計してから÷6**、負数は `Math.trunc` ではなく **`Math.floor`**（Rubyの `Integer#/` が切り下げるため）。
- **描画先はERB側に点在する。** `show.html.erb` の `#round-panel` / `#buff-list-panel` / `#formula-panel` へ `createPortal` で差し込む。単一のreducerで扱うためルートは1つ（`[data-react-root]`）に保つ。
- **初期データは `data-combat-state` 属性で渡す。** Railsが属性値を自動エスケープするため `html_safe` が不要。
- **保存は `authenticity_token` をJSONボディに含める。** `sendBeacon` はヘッダを付けられないため。`Blob` の `type` は `application/json` 必須（サーバ側はそれ以外を415で弾く）。また **`sendBeacon` は必ずPOSTで送る**ため、ルーティングは `PATCH|PUT|POST` を受ける。
- **Turboの遷移は `turbo:before-fetch-request` で待たせてから保存する。** `turbo:before-visit` では間に合わない（Turboはフォーム送信のレスポンス＝新しいページのHTMLを受け取ってから visit を提案するため、サーバが古いDB状態で描画してしまう）。
- **`show` は `turbo-cache-control: no-cache`。** キャッシュから復元されると `data-combat-state` が古いDB状態のまま復活し、次の操作で保存済みの値を上書きする。
- **保存に失敗しても楽観的更新はロールバックしない。** 戦闘中にチェックが勝手に戻るのは体験を悪化させるため、「未保存」を表示して再試行する（#136 の決定）。
- 送るスナップショットは**キーを省略しない**。`remaining_rounds` を落とすとサーバ側で更新されず、無限持続バフと区別できなくなる。

バフと武器の**作成・編集・削除はRailsのページ遷移のまま**。これらはキャラクターシート管理の責務で、戦闘中に頻発しない。Reactが描画するバフ行の「編集」はリンク、「削除」は `_method=delete` + `authenticity_token` を持つフォームとして出力し、Turboが拾う。

### 判定式の仕様

- 命中: `2d6+<冒険者レベル + DEXボーナス + 命中補正>+<DEXバフ合計>`
- ダメージ: `k<威力>[<クリティカル値>]+<固定値 + STR/damageバフ合計><特殊トークン>`

計算上の重要なルール:

- **`value_kind`**: `fixed` はそのまま加算、`ability`（能力値そのものを上げるバフ）は**合計してから**6で割った商を加算する。個別に割ると `+4` と `+4` が `0+0` になる。
- **`special_type`**: 通常の `bonus_value` 加算で表現できない特殊バフ。判定式の末尾へトークンをポン付けする（`critical_ray` → `$+x`、`kubikari` → `r5`）。`dice_fix` は種別として存在するが判定式へは反映していない。integerではなくstring enumで保存しているのは、後から並べ替えてもズレず管理人がDBを直読みして意味が分かるようにするため。
- **`active`**: `false` のバフは判定式から除外される。**新規登録・更新の直後は必ず `active: false`**（`BuffPreset#build_buff_for` / `BuffsController#create_buff_manual` / `#resynced_attrs`）。ユーザーが明示的にトグルするまで判定式が黙って変わらないようにするための仕様。
- **ラウンド進行**: `remaining_rounds` を増減し、0になると `active: false` に落ちる。`remaining_rounds` が nil のバフは無限持続として増減対象外。`reset_round` は持続ラウンドを持つバフだけを初期値へ戻す。

### 認証

`ApplicationController` で全ページ `authenticate_user!`（Deviseコントローラは除外）。公開ページは `TopController#index` と `PagesController`（利用規約・プライバシー・問い合わせ・ガイド）で個別に `skip_before_action` している。キャラクター取得は必ず `current_user.characters.find(...)` 経由。

## CI / デプロイ

PR と `main` への push で `.github/workflows/ci.yml` が4ジョブを実行する: `scan_ruby`（Brakeman + bundler-audit）、`lint`（RuboCop）、`frontend`（`tsc --noEmit` + `vitest run`）、`rspec`（PostgreSQLサービスコンテナ + yarn build / build:css の後に実行）。

本番は Render（Web）+ Neon（PostgreSQL）で、構成は `render.yaml`、手順は `docs/deploy.md`。

- メール送信は Render が SMTP ポートを遮断するため Resend の HTTP API（`config.action_mailer.delivery_method = :resend`）を使う。
- **キャッシュ・ジョブ・Action Cable はDBを使わない構成にしている**（`:memory_store` / `:async` / cable も `async`）。Neon無料プランのcompute枠は月100 CU-hours で、solid_queue や solid_cable のポーリングを動かすと16〜17日で使い切るため。この判断に伴い3つのgemもGemfileから外してある。詳細と注意点は `docs/deploy.md` 参照。
- Render のスピンダウン対策として、Google Apps Script が10分おきにトップページを叩いている。DBに触らないパスなので Neon は寝たままで、これが意図した状態。
