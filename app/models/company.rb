class Company < ApplicationRecord
    validates :name, presence: true

    validates :subdomain, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]{2,30}\z/ }
end
