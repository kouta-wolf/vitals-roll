class CreateWeapons < ActiveRecord::Migration[8.1]
  def change
    create_table :weapons do |t|
      t.references :character, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :power, default: 0
      t.integer :critical, default: 10
      t.integer :fixed_value, default: 0
      t.integer :fixed_hit_rate, default: 0

      t.timestamps
    end
  end
end
