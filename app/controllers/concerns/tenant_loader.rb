# frozen_string_literal: true

module TenantLoader
  extend ActiveSupport::Concern

  included do
    around_action :with_tenant
    before_action :authenticate_user!
    before_action :verify_user_company
  end

  private

  def with_tenant
    token_company_id = verified_company_id

    unless token_company_id.present?
      raise Errors::TenantNotFound, "Invalid token: company is missing"
    end

    company = Company.find_by(id: token_company_id)

    unless company
      raise Errors::TenantNotFound, "Company not found"
    end

    Apartment::Tenant.switch(company.subdomain) { yield }
  rescue Apartment::TenantNotFound
    raise Errors::TenantNotFound, "Company tenant not found"
  ensure
    Apartment::Tenant.reset
  end

  def verify_user_company
    return unless user_signed_in?

    token_company_id = verified_company_id

    unless token_company_id.present? &&
           current_user.company_id.to_s == token_company_id.to_s
      raise Errors::Forbidden, "User does not belong to this company"
    end
  end

  def verified_company_id
    return @verified_company_id if defined?(@verified_company_id)

    token = request.headers["Authorization"]&.split(" ")&.last

    @verified_company_id = if token.present?
                            payload, = JWT.decode(
                              token,
                              Rails.application.secret_key_base,
                              true,
                              algorithm: "HS256"
                            )

                            payload["company_id"]
    end
  rescue JWT::DecodeError
    @verified_company_id = nil
  end
end
