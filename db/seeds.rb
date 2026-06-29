if Rails.env.development?
  # 空状態の確認用ユーザーデータ
  User.find_or_create_by!(email: "blank@test.com") do |u|
    u.password = "password"
  end

  # 大量データの確認用ユーザーデータ
  full_user = User.find_or_create_by!(email: "full@test.com") do |u|
    u.password = "password"
  end

  if full_user.characters.count < 30
    30.times do
      full_user.characters.create!(
        name:         Faker::Games::DnD.name,
        dexterity:    rand(6..18),
        agility:      rand(6..18),
        strength:     rand(6..18),
        vitality:     rand(6..18),
        intelligence: rand(6..18),
        spirit:       rand(6..18)
      )
    end
  end
end
