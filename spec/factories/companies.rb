FactoryBot.define do
  factory :company do
    name { Faker::Company.name }

    sequence(:subdomain) do |n|
      "tenant_#{n}"
    end
  end
end
