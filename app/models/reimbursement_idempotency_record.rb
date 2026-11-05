class ReimbursementIdempotencyRecord < ApplicationRecord
  belongs_to :expense
  belongs_to :actor, class_name: "User"

  validates :idempotency_key, presence: true
  validates :response_body, presence: true
  validates :response_status, presence: true
end
