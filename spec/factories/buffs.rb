FactoryBot.define do
  factory :buff do
    association :character
    name { "テストバフ" }
    target_status { "strength" }
    bonus_value   { 1 }
    duration_rounds { 3 }
    remaining_rounds { 3 }
    active { false }
    # buff_presetはデフォルトnil（カスタムバフ）

    trait :from_preset do
      association :buff_preset
      name { nil } # プリセット由来はbuff_preset.name経由で参照するため保持しない
    end
  end
end
