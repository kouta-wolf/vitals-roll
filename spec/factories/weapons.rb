FactoryBot.define do
  factory :weapon do
    association :character
    name { "テストソード" }
    power { 25 }
    critical { 10 }
    fixed_value { 1 }
    fixed_hit_rate { 0 }
  end
end
