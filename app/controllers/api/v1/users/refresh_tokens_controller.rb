module Api
  module V1
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

        unless refresh_record
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
          refresh_record.with_lock do
            if refresh_record.revoked_at.present?
              revoke_other_active_tokens(refresh_record)

              render json: { error: "Refresh token reuse detected" },
                    status: :unauthorized
              next
            end

            if refresh_record.expires_at <= Time.current
              render json: { error: "Invalid or expired refresh token" },
                    status: :unauthorized
              next
            end

            user = User.find_by(
              id: refresh_record.user_id,
              company_id: company.id
            )

            unless user
              render json: { error: "User not found in this company" },
                    status: :unauthorized
              next
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
        end
      ensure
        Apartment::Tenant.reset
      end

      private

      def revoke_other_active_tokens(refresh_record)
        RefreshToken.where(
          company_id: refresh_record.company_id,
          user_id: refresh_record.user_id,
          revoked_at: nil
        ).where(
          "expires_at > ?", Time.current
        ).update_all(
          revoked_at: Time.current,
          updated_at: Time.current
        )
      end
    end
  end
end
