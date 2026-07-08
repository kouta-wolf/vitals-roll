FactoryBot.define do
  factory :buff_preset do
    # name に uniqueness があるため、複数生成でも衝突しないよう sequence を使う
    sequence(:name) { |n| "テストバフ#{n}" }
    target_status { "strength" }
    bonus_value   { 1 }
    duration_rounds { 3 }
    # special_type はデフォルト nil（通常バフ）

    trait :special do
      special_type { "critical_ray" }
      target_status { nil }   # 特殊バフは対象ステータスを持たない
    end
  end
end
