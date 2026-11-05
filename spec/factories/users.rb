FactoryBot.define do
  factory :user do
    association :company

    sequence(:email) do |n|
      "user#{n}@example.com"
    end

    password { "password123" }
    password_confirmation { password }

    role { :member }

    jti { SecureRandom.uuid }

    trait :admin do
      role { :admin }
    end
  end
end
