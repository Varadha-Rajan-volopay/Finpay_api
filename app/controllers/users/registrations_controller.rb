class Users::RegistrationsController < Devise::RegistrationsController
  respond_to :json

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
  rescue ArgumentError => e
    render json: {
      error: e.message
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
