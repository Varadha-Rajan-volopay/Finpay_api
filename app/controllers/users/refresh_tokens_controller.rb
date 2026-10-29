class Users::RefreshTokensController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :verify_user_company, raise: false
  skip_around_action :with_tenant, raise: false

  def create
    raw_refresh_token = params[:refresh_token]

    unless raw_refresh_token.present?
      render json: { error: "Refresh token is required" },
             status: :unauthorized
      return
    end

    refresh_record = RefreshToken.find_by(
      token_digest: RefreshToken.digest(raw_refresh_token)
    )

    unless refresh_record&.active?
      render json: { error: "Invalid or expired refresh token" },
             status: :unauthorized
      return
    end

    company = Company.find_by(id: refresh_record.company_id)

    unless company
      render json: { error: "Company not found" },
             status: :unauthorized
      return
    end

    Apartment::Tenant.switch(company.subdomain) do
      user = User.find_by(
        id: refresh_record.user_id,
        company_id: company.id
      )

      unless user
        render json: { error: "User not found in this company" },
               status: :unauthorized
        return
      end

      access_token, = Warden::JWTAuth::UserEncoder.new.call(
        user,
        :user,
        nil
      )

      RefreshToken.transaction do
        refresh_record.revoke!

        _new_record, new_refresh_token =
          RefreshToken.issue!(
            company_id: company.id,
            user_id: user.id
          )

        render json: {
          access_token: access_token,
          refresh_token: new_refresh_token,
          user: {
            id: user.id,
            email: user.email,
            company_id: user.company_id,
            role: user.role
          }
        }, status: :ok
      end
    end
  ensure
    Apartment::Tenant.reset
  end
end
