FactoryBot.define do
  factory :company do
    name { Faker::Company.name }

    sequence(:subdomain) do |n|
      "tenant#{n}#{SecureRandom.hex(4)}"
    end
  end
end
