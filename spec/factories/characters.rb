FactoryBot.define do
  factory :character do
    association :user
    name { "テスター・ドラゴン" }
    race { "テストドレイク" }
    main_class { "ファイター" }
    main_class_level { 3 }
    dexterity { 12 }
    agility { 12 }
    strength { 12 }
    vitality { 12 }
    intelligence { 12 }
    spirit { 12 }
    defense { 4 }
  end
end
