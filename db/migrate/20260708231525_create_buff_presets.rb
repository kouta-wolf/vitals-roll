class CreateBuffPresets < ActiveRecord::Migration[8.1]
  def change
    create_table :buff_presets do |t|
      t.string  :name,           null: false
      t.string  :target_status               # 通常バフのみ使用(モデルで条件付き必須)
      t.integer :bonus_value,    null: false
      t.integer :duration_rounds             # null = 効果が無限に持続
      t.string  :special_type                # null = 通常バフ
      t.timestamps
    end
    add_index :buff_presets, :name, unique: true
  end
end
