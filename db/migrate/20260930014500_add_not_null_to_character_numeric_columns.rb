class AddNotNullToCharacterNumericColumns < ActiveRecord::Migration[8.1]
  # main_class_level / defense / current_rounds はデフォルト値を持つだけでNOT NULLが無く、
  # フォームで空欄送信するとNULLが保存できてしまった。
  # main_class_level がNULLだと Character#hit_formula が NoMethodError になり、
  # 武器を登録済みのキャラクターでは詳細ページ全体が500になる（#168）。

  # アプリの Character とは別物。マイグレーションはその時点のテーブルに対して
  # 動き続ける必要があるため、default_scope やバリデーションの追加、リネームの影響を
  # 受けないよう、このマイグレーション専用のモデルを使う。
  class MigrationCharacter < ActiveRecord::Base
    self.table_name = "characters"
  end

  def up
    # NOT NULL を付ける前に、既存のNULL行をカラムのデフォルト値で埋める
    MigrationCharacter.where(main_class_level: nil).update_all(main_class_level: 1)
    MigrationCharacter.where(defense: nil).update_all(defense: 0)
    MigrationCharacter.where(current_rounds: nil).update_all(current_rounds: 1)

    # 下限バリデーションを下回る既存行も正規化する。
    # これらのカラムはこれまでサーバ側の検証が無く、フォームのmin属性は
    # ブラウザを経由しない更新では効かないため、不正な値が入っている可能性がある。
    # 残したままにすると reset_round! の update! が RecordInvalid で落ちる。
    # ..0 は「0以下」、...0 は「0未満」を表す終端のみのRange。
    MigrationCharacter.where(main_class_level: ..0).update_all(main_class_level: 1)
    MigrationCharacter.where(defense: ...0).update_all(defense: 0)
    MigrationCharacter.where(current_rounds: ...0).update_all(current_rounds: 0)

    change_column_null :characters, :main_class_level, false
    change_column_null :characters, :defense, false
    change_column_null :characters, :current_rounds, false
  end

  def down
    change_column_null :characters, :main_class_level, true
    change_column_null :characters, :defense, true
    change_column_null :characters, :current_rounds, true
  end
end
