class CreateBuffs < ActiveRecord::Migration[8.1]
  def change
    create_table :buffs do |t|
      t.references :character,   null: false, foreign_key: true
      t.references :buff_preset, foreign_key: true # カスタムバフはnull
      t.string  :name                          # プリセット由来はnull(buff_preset.name参照)
      t.string  :target_status                 # プリセットと同様、通常バフのみ使用
      t.integer :bonus_value,    null: false
      t.integer :duration_rounds                # null = 効果が無限に持続
      t.integer :remaining_rounds                # null = 無限持続。ラウンド進行で自動減算
      t.boolean :active, null: false, default: false
      t.timestamps
    end
  end
end
