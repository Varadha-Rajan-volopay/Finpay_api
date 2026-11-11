
module Api
  module V1
    module Users
      class UserRegistrationsController < ApplicationController
        before_action :require_admin!

        def create
          user = User.new(user_params)
          user.company_id = current_user.company_id
          user.role = :member

          if user.save
            render json: {
              message: "User registered successfully",
              user: {
                id: user.id,
                email: user.email,
                role: user.role,
                company_id: user.company_id
              }
            }, status: :created
          else
            render json: {
              errors: user.errors.full_messages
            }, status: :unprocessable_entity
          end
        end

        private

        def require_admin!
          return if current_user.admin?

          render json: {
            error: "Only company admins can register users"
          }, status: :forbidden
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
end
