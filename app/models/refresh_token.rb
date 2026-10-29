class RefreshToken < ApplicationRecord
  TOKEN_LIFETIME = 30.days

  validates :company_id, :user_id, :token_digest, :expires_at, presence: true
  validates :token_digest, uniqueness: true

  def self.issue!(company_id:, user_id:)
    raw_token = SecureRandom.urlsafe_base64(64)

    record = create!(
      company_id: company_id,
      user_id: user_id,
      token_digest: digest(raw_token),
      expires_at: TOKEN_LIFETIME.from_now
    )

    [ record, raw_token ]
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def active?
    revoked_at.nil? && expires_at.future?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
