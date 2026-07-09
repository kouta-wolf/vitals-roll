# アプリ提供のバフプリセット（本番にも投入するため development ガードの外に置く）
buff_presets = [
  {
    name:            "クリティカルレイ",
    target_status:   nil,
    bonus_value:     1,
    duration_rounds: nil,
    special_type:    "critical_ray"
  },
  {
    name:            "首刈り刀",
    target_status:   nil,
    bonus_value:     0,
    duration_rounds: nil,
    special_type:    "kubikari"
  },
  {
    name:            "マッスルベアー",
    target_status:   "strength",
    bonus_value:     12,
    duration_rounds: 3,
    special_type:    nil
  }
]

buff_presets.each do |attrs|
  BuffPreset.find_or_create_by!(name: attrs[:name]) do |bp|
    bp.assign_attributes(attrs.except(:name))
  end
end

if Rails.env.development?
  # 空状態の確認用ユーザーデータ
  User.find_or_create_by!(email: "blank@test.com") do |u|
    u.password = "password"
  end

  # 大量データの確認用ユーザーデータ
  full_user = User.find_or_create_by!(email: "full@test.com") do |u|
    u.password = "password"
  end

  races = %w[ニンゲン エルフ ドワーフ ナイトメア ルーンフォーク]
  main_classes = %w[ファイター フェンサー グラップラー ソーサラー プリースト]

  if full_user.characters.count < 30
    30.times do
      full_user.characters.create!(
        name:             Faker::Games::DnD.name,
        race:             races.sample,
        main_class:       main_classes.sample,
        main_class_level: rand(1..15),
        dexterity:        rand(6..18),
        agility:          rand(6..18),
        strength:         rand(6..18),
        vitality:         rand(6..18),
        intelligence:     rand(6..18),
        spirit:           rand(6..18)
      )
    end
  end
end
