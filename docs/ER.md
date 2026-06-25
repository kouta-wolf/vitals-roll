# ER図

## テーブル概要

| テーブル名 | 役割 |
| --- | --- |
| users | ログインユーザー。Deviseでの認証管理 |
| characters | ユーザー所有のSW2.5キャラクター。SW2.5の基本ステータスを保持 |
| weapons | キャラクターが装備する武器。判定式の生成に使用 |
| buff_presets | よく使うバフの雛形。アプリ提供のプリセットとして全ユーザーで共有 |
| buffs | キャラクターに実際にかかっているバフの実体。プリセットから生成するか手動で直接登録できる |

## Mermaid

```mermaid
erDiagram

    users {
        bigint id PK "ユーザーID"
        string email "メールアドレス"
        string encrypted_password "パスワード(Devise)"
        string reset_password_token "パスワードリセット用トークン(Devise)"
        datetime reset_password_sent_at "パスワードリセット送信日時(Devise)"
        datetime remember_created_at "ログイン保持の有効化日時(Devise)"
        datetime created_at "作成日時"
        datetime updated_at "更新日時"
    }

    characters {
        bigint id PK "キャラクターID"
        bigint user_id FK "所有ユーザーID"
        string name "キャラクター名"
        string race "種族"
        string main_class "メイン技能"
        integer main_class_level "冒険者レベル"
        integer dexterity "器用度"
        integer agility "敏捷度"
        integer strength "筋力"
        integer vitality "生命力"
        integer intelligence "知力"
        integer spirit "精神力"
        integer defense "防護点"
        integer current_rounds "現在のラウンド数(将来的にsessionsテーブルへ移行)"
        datetime created_at "作成日時"
        datetime updated_at "更新日時"
    }

    weapons {
        bigint id PK "武器ID(主キー)"
        bigint character_id FK "所有キャラクターID"
        string name "武器名"
        integer power "威力"
        integer critical "クリティカル値"
        integer fixed_value "ダメージ固定値"
        integer fixed_hit_rate "命中補正値"
        datetime created_at "作成日時"
        datetime updated_at "更新日時"
    }

    buff_presets {
        bigint id PK "プリセットID(主キー)"
        string name "バフ名"
        string target_status "対象ステータス"
        integer bonus_value "補正値"
        integer duration_rounds "持続ラウンド数(nullは無限対応)"
        string special_type "特殊処理"
        datetime created_at "作成日時"
        datetime updated_at "更新日時"
    }

    buffs {
        bigint id PK "バフID(主キー)"
        bigint character_id FK "対象キャラクターID"
        bigint buff_preset_id FK "参照プリセットID(nullは個別作成で)"
        string name "バフ名"
        string target_status "対象ステータス"
        integer bonus_value "補正値"
        integer duration_rounds "持続ラウンド数(nullは無限)"
        integer remaining_rounds "残りラウンド数"
        boolean active "有効スイッチ"
        datetime created_at "作成日時"
        datetime updated_at "更新日時"
    }

    users ||--o{ characters : "has many ユーザーがキャラを所持"
    characters ||--o{ weapons : "has many キャラが武器を所持"
    characters ||--o{ buffs : "has many キャラがバフを所持"
    buff_presets ||--o{ buffs : "has many 任意で作成するバフとは別にプリセットがある"
```

## 設計メモ

- **buff_presetsとbuffsの分離**：buff_presetsはアプリ全体で共有する雛形テーブルでcharacter_idを持たない。buffsはキャラクターに実際にかかっている実体のバフで、プリセットから生成した場合はbuff_preset_idを持ち、手動登録したカスタムバフはnullになる。
- **weaponsテーブルの分離**：SW2.5は武器2つ持ちの技能があるため将来的に分離できるように今から調整とした。
- **current_roundsの位置**：現在はcharactersテーブルに持たせているが、将来的に複数人セッション機能を追加する際はsessionsテーブル等を設けてそこに移行することを検討。
- **special_type**：通常の補正では表現できない特殊な処理（クリティカル値変更・ダイス目固定など）を文字列enumで区別するカラム。判定式の組み立てロジックで参照する。
- **active**：バフはオン/オフを切り替えて一時的に無効化できる。activeがfalseのバフは判定式の計算から除外される。
