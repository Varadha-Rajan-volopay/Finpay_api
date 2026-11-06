module Api
  module V1
    class Users::RegistrationsController < Devise::RegistrationsController
      respond_to :json

      rate_limit to: 5,
                within: 1.hour,
                by: -> { request.remote_ip },
                with: -> {
                  render json: {
                    error: "Too many registration attempts. Please try again later."
                  }, status: :too_many_requests
                }

      skip_before_action :authenticate_user!, raise: false
      skip_before_action :verify_user_company, raise: false
      skip_around_action :with_tenant, raise: false

      def create
        user = nil

        company = Companies::Provision.call(
          name: company_params[:name],
          subdomain: company_params[:subdomain]
        ) do |provisioned_company|
          user = User.new(user_params)
          user.company_id = provisioned_company.id
          user.role = :admin
          user.save!
        end

        render json: {
          message: "Company and admin user registered successfully",
          company: {
            id: company.id,
            name: company.name,
            subdomain: company.subdomain
          },
          user: {
            id: user.id,
            email: user.email,
            role: user.role
          }
        }, status: :created

      rescue ActiveRecord::RecordInvalid => e
        render json: {
          errors: e.record.errors.full_messages
        }, status: :unprocessable_entity

      rescue Companies::Provision::TenantSchemaAlreadyExists
        render json: {
          error: "This company subdomain is already registered"
        }, status: :conflict

      rescue ActiveRecord::RecordNotUnique
        render json: {
          error: "This company subdomain is already registered"
        }, status: :conflict
      end

      private

      def company_params
        params.require(:company).permit(
          :name,
          :subdomain
        )
      end

      def user_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation
        )
      end
    end
  end
end
