# デプロイ手順（Render + Neon）

本番環境は **Render**（Webサービス・無料プラン）でアプリを動かし、**Neon**（マネージドPostgreSQL・無料プラン）をDBとして利用する。

- 本番URL: https://vitals-roll.onrender.com
- デプロイ元ブランチ: `main`（push で自動再デプロイ）
- インフラ構成は [`render.yaml`](../render.yaml) にコードで定義（Blueprint）

## 全体の流れ

1. Neon でDBを作成し、接続文字列（`DATABASE_URL`）を取得
2. `config/database.yml` の production を `DATABASE_URL` 1本に集約（実装済み）
3. `render.yaml` を用意（実装済み）
4. `main` に push
5. Render の Blueprint からデプロイ → 管理画面で秘密の環境変数を入力
6. 動作確認

## 1. Neon

1. [Neon](https://neon.tech/) でプロジェクト作成
2. **Connection Details** から接続文字列をコピー（= `DATABASE_URL`）
   - **Pooled connection**（ホスト名に `-pooler` が付く方）を使う
   - `...?sslmode=require` が付いた形でOK
3. 無料枠はアイドルで自動サスペンドするため、放置後の初回アクセスは数秒待たされる（仕様）

## 2. database.yml（Rails 8 マルチDB → 単一DBへ集約）

Rails 8 は `primary` / `cache`（solid_cache）/ `queue`（solid_queue）/ `cable`（solid_cable）の
4つのDBを使う構成になっている。Neon 無料枠はDB1つなので、4接続すべてを同じ `DATABASE_URL` に向ける。
solid系はテーブル名が異なるため同一DBに同居できる。

```yaml
production:
  primary: &primary_production
    <<: *default
    url: <%= ENV["DATABASE_URL"] %>
  cache:
    <<: *primary_production
    migrations_paths: db/cache_migrate
  queue:
    <<: *primary_production
    migrations_paths: db/queue_migrate
  cable:
    <<: *primary_production
    migrations_paths: db/cable_migrate
```

> development / test には影響しない（変更したのは production ブロックのみ）。

## 3. render.yaml

```yaml
services:
  - type: web
    name: vitals-roll
    runtime: ruby
    plan: free
    buildCommand: "bundle install && yarn install && bundle exec rails db:prepare assets:precompile"
    startCommand: "bundle exec rails server -b 0.0.0.0 -p $PORT"
    envVars:
      - key: RAILS_ENV
        value: production
      - key: RAILS_MASTER_KEY
        sync: false
      - key: DATABASE_URL
        sync: false
```

- `buildCommand`: gem（`bundle install`）、JS/CSS依存（`yarn install`）、DB準備、アセット生成
- `startCommand`: `$PORT` は Render が自動注入
- `sync: false`: 値は `render.yaml` に書かず、Render管理画面で手入力（秘密情報をGitに入れない）

## 4. 環境変数（Render管理画面で入力）

| 変数 | 値 | 備考 |
| --- | --- | --- |
| `RAILS_ENV` | `production` | render.yaml に直書き |
| `DATABASE_URL` | Neon の接続文字列 | `sync: false`。手入力 |
| `RAILS_MASTER_KEY` | `cat config/master.key` の中身（32桁hex） | `sync: false`。手入力 |

## ハマったポイント（重要）

### ① `RAILS_SERVE_STATIC_FILES` は Rails 8 では不要

Rails 7 までは静的ファイル配信をこの env で切り替えていたが、**Rails 8 は `public_file_server.enabled`
のデフォルトが `true`** で、この変数を読むコードが存在しない。設定しても無意味なので入れない。

### ② `buildCommand` を明示すると `bundle install` が自動実行されない

`render.yaml` で `buildCommand` を指定すると Render 既定の依存インストールを**上書き**する。
そのため `bundle install` と `yarn install` を自分でビルドコマンドに含める必要がある。
（含めないと `Could not find rails-x.x.x ... (Bundler::GemNotFound)` で失敗する）

JS/CSS は jsbundling(esbuild) + cssbundling(tailwind) を使っており、`assets:precompile` が
`yarn build` / `yarn build:css` を呼ぶため `yarn install` が必須。

### ③ `RAILS_MASTER_KEY` の値ミス → `key must be 16 bytes`

ビルド/起動時に `ArgumentError: key must be 16 bytes` が出たら、Render の `RAILS_MASTER_KEY` の
**値が壊れている**（credentials を AES-128 で復号できない）。原因はほぼ以下:

- 前後に引用符 `"..."` を付けた
- コピー時に末尾の改行・空白が混入
- 文字が欠けている（32文字ちょうどか確認）
- 別の値を貼った

`cat config/master.key` の32桁hexを、余分な文字なしで貼り直す。

## 5. 動作確認

- トップページが 200 で表示される
- Tailwind のスタイルが当たっている（静的配信＋precompile成功の確認）
- DBを使う操作（キャラ作成・Devise登録/ログイン）が通る

## 補足

- **Puma の警告** `Detected running cluster mode with 1 worker.` は無害。
  メモリ節約のためシングルモードにするなら `WEB_CONCURRENCY=0` を設定する（無料枠なら任意）。
- `db:prepare` は4DB分のマイグレーションを実行する。マイグレーション追加時は再デプロイで自動反映される。