# frozen_string_literal: true

module AuthenticationHelpers
  def auth_token_for(user)
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    token
  end

  def auth_token_payload(token)
    JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    ).first
  end

  def expired_auth_token_for(user)
    payload = auth_token_payload(auth_token_for(user))
    payload["exp"] = 1.hour.ago.to_i

    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end

  def wrong_tenant_auth_token_for(user, company_id:)
    payload = auth_token_payload(auth_token_for(user))
    payload["company_id"] = company_id

    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end

  def revoked_auth_token_for(user)
    token = auth_token_for(user)
    payload = auth_token_payload(token)

    JwtDenylist.create!(
      jti: payload.fetch("jti"),
      exp: Time.at(payload.fetch("exp"))
    )

    token
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers
end
