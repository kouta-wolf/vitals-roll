class AddNotNullToCharacterNumericColumns < ActiveRecord::Migration[8.1]
  # main_class_level / defense / current_rounds はデフォルト値を持つだけでNOT NULLが無く、
  # フォームで空欄送信するとNULLが保存できてしまった。
  # main_class_level がNULLだと Character#hit_formula が NoMethodError になり、
  # 武器を登録済みのキャラクターでは詳細ページ全体が500になる（#168）。
  def up
    # NOT NULL を付ける前に、既存のNULL行をカラムのデフォルト値で埋める。
    # モデル経由だと将来モデルが変わったときにマイグレーションが壊れるため生SQLで行う。
    execute <<~SQL.squish
      UPDATE characters SET main_class_level = 1 WHERE main_class_level IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE characters SET defense = 0 WHERE defense IS NULL
    SQL
    execute <<~SQL.squish
      UPDATE characters SET current_rounds = 1 WHERE current_rounds IS NULL
    SQL

    # 下限バリデーションを下回る既存行も正規化する。
    # これらのカラムはこれまでサーバ側の検証が無く、フォームのmin属性は
    # ブラウザを経由しない更新では効かないため、不正な値が入っている可能性がある。
    # 残したままにすると reset_round! の update! が RecordInvalid で落ちる。
    execute <<~SQL.squish
      UPDATE characters SET main_class_level = 1 WHERE main_class_level < 1
    SQL
    execute <<~SQL.squish
      UPDATE characters SET defense = 0 WHERE defense < 0
    SQL
    execute <<~SQL.squish
      UPDATE characters SET current_rounds = 0 WHERE current_rounds < 0
    SQL

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
