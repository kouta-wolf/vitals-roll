class AddValueKindToBuffPresetsAndBuffs < ActiveRecord::Migration[8.1]
  # value_kind: bonus_valueの単位。
  #   fixed   = 判定式へそのまま加算する固定値/ボーナス値
  #   ability = 能力値そのものの増減。ボーナス換算(÷6切り捨て)を経てから加算する
  # 既存データは全て固定値扱いのためデフォルトは "fixed"。
  def change
    add_column :buff_presets, :value_kind, :string, null: false, default: "fixed"
    add_column :buffs, :value_kind, :string, null: false, default: "fixed"
  end
end
