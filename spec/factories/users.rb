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
  end
end
