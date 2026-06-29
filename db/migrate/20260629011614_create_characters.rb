class CreateCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :characters do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :race
      t.string :main_class
      t.integer :main_class_level, default: 1
      t.integer :dexterity, null: false
      t.integer :agility, null: false
      t.integer :strength, null: false
      t.integer :vitality, null: false
      t.integer :intelligence, null: false
      t.integer :spirit, null: false
      t.integer :defense, default: 0
      t.integer :current_rounds, default: 1

      t.timestamps
    end
  end
end
