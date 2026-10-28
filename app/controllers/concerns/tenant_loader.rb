module TenantLoader
  extend ActiveSupport::Concern

  included do
    around_action :with_tenant
    before_action :authenticate_user!
    before_action :verify_user_company
  end

  private

  def with_tenant
    company_id = verified_company_id

    unless company_id.present?
      render json: {
        error: "Invalid or missing company in token"
      }, status: :unauthorized

      return
    end

    company = Company.find_by(id: company_id)

    unless company
      render json: {
        error: "Company not found"
      }, status: :unauthorized

      return
    end

    Apartment::Tenant.switch(company.subdomain) do
      yield
    end
  rescue Apartment::TenantNotFound
    render json: {
      error: "Company tenant not found"
    }, status: :unauthorized
  ensure
    Apartment::Tenant.reset
  end

  def verify_user_company
    return unless user_signed_in?

    token_company_id = verified_company_id

    unless token_company_id.present? &&
           current_user.company_id.to_s == token_company_id.to_s
      render json: {
        error: "User does not belong to this company"
      }, status: :forbidden
    end
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
