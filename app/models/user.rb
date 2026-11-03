class User < ApplicationRecord
  belongs_to :company

  before_create :generate_jti

  enum :role, {
    admin: 0,
    member: 1
  }

  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  def jwt_payload
    {
      "sub" => id.to_s,
      "scp" => "user",
      "company_id" => company_id,
      "role" => role
    }
  end

  private

  def generate_jti
    self.jti ||= SecureRandom.uuid
  end
end
