FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "test_#{n}@email.com" }
    password { "password" }
    password_confirmation { "password" }
  end
end
