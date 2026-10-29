module TenantLoader
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    around_action :with_tenant
  end

  private

  def with_tenant
    return unless user_signed_in?

    token_company_id = verified_company_id

    unless token_company_id.present?
      render json: { error: "Invalid token: company is missing" },
             status: :unauthorized
      return
    end

    unless current_user.company_id.to_s == token_company_id.to_s
      render json: { error: "User does not belong to this company" },
             status: :forbidden
      return
    end

    tenant_name = current_user.company.subdomain

    Apartment::Tenant.switch(tenant_name) do
      yield
    end
  rescue Apartment::TenantNotFound
    render json: { error: "Company tenant not found" },
           status: :unauthorized
  ensure
    Apartment::Tenant.reset
  end

  def verified_company_id
    token = request.headers["Authorization"]&.split(" ")&.last
    return unless token.present?

    payload, = JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    )

    payload["company_id"]
  rescue JWT::DecodeError
    nil
  end
end