class Users::MeController < ApplicationController
  def show
    authorize current_user, :show?

    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        company_id: current_user.company_id,
        role: current_user.role
      }
    }, status: :ok
  end
end
