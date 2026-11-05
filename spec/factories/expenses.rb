FactoryBot.define do
  factory :expense do
    association :user
    association :category

    title { "Team lunch" }
    amount_cents { 1050 }
    currency { "INR" }
    status { "pending" }
    incurred_on { Date.current }
    notes { "Lunch expense" }
  end
end
