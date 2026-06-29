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
