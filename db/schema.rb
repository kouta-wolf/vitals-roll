# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_30_004825) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "buff_presets", force: :cascade do |t|
    t.integer "bonus_value", null: false
    t.datetime "created_at", null: false
    t.integer "duration_rounds"
    t.string "name", null: false
    t.string "special_type"
    t.string "target_status"
    t.datetime "updated_at", null: false
    t.string "value_kind", default: "fixed", null: false
    t.index ["name"], name: "index_buff_presets_on_name", unique: true
  end

  create_table "buffs", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.integer "bonus_value", null: false
    t.bigint "buff_preset_id"
    t.bigint "character_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration_rounds"
    t.string "name"
    t.integer "remaining_rounds"
    t.string "target_status"
    t.datetime "updated_at", null: false
    t.string "value_kind", default: "fixed", null: false
    t.index ["buff_preset_id"], name: "index_buffs_on_buff_preset_id"
    t.index ["character_id"], name: "index_buffs_on_character_id"
  end

  create_table "characters", force: :cascade do |t|
    t.integer "agility", null: false
    t.datetime "created_at", null: false
    t.integer "current_rounds", default: 1
    t.integer "defense", default: 0
    t.integer "dexterity", null: false
    t.integer "intelligence", null: false
    t.string "main_class"
    t.integer "main_class_level", default: 1
    t.string "name", null: false
    t.string "race"
    t.integer "spirit", null: false
    t.integer "strength", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "vitality", null: false
    t.index ["user_id"], name: "index_characters_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "weapons", force: :cascade do |t|
    t.bigint "character_id", null: false
    t.datetime "created_at", null: false
    t.integer "critical", default: 10
    t.integer "fixed_hit_rate", default: 0
    t.integer "fixed_value", default: 0
    t.string "name", null: false
    t.integer "power", default: 0
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_weapons_on_character_id"
  end

  add_foreign_key "buffs", "buff_presets"
  add_foreign_key "buffs", "characters"
  add_foreign_key "characters", "users"
  add_foreign_key "weapons", "characters"
end
