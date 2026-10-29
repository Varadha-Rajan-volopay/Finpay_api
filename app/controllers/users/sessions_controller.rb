class Users::SessionsController < Devise::SessionsController
  respond_to :json

  skip_before_action :authenticate_user!
  skip_before_action :verify_user_company
  skip_around_action :with_tenant

  skip_before_action :verify_signed_out_user,
                     only: :destroy,
                     raise: false

  def create
    company = Company.find_by(
      subdomain: params.dig(:company, :subdomain)
    )

    unless company
      render_invalid_credentials
      return
    end

    Apartment::Tenant.switch(company.subdomain) do
      self.resource = warden.authenticate(auth_options)

      unless resource && resource.company_id.to_s == company.id.to_s
        render_invalid_credentials
        return
      end

      sign_in(resource_name, resource, store: false)

      _refresh_record, refresh_token =
        RefreshToken.issue!(
          company_id: resource.company_id,
          user_id: resource.id
        )

      access_token = response.headers["Authorization"]&.split(" ")&.last

      render json: {
        message: "Login successful",
        access_token: access_token,
        refresh_token: refresh_token,
        user: {
          id: resource.id,
          email: resource.email,
          company_id: resource.company_id,
          role: resource.role
        }
      }, status: :ok
    end
  ensure
    Apartment::Tenant.reset
  end

  def destroy
    token = request.headers["Authorization"]&.split(" ")&.last

    unless token.present?
      render json: { error: "Missing token" },
             status: :unauthorized
      return
    end

    payload, = JWT.decode(
      token,
      Rails.application.secret_key_base,
      true,
      algorithm: "HS256"
    )

    jti = payload["jti"]
    exp = payload["exp"]

    unless jti.present? && exp.present?
      render json: { error: "Invalid token" },
             status: :unauthorized
      return
    end

    JwtDenylist.find_or_create_by!(jti: jti) do |record|
      record.exp = Time.at(exp)
    end

    # Revoke the refresh token if the client supplies it.
    raw_refresh_token = params[:refresh_token]

    if raw_refresh_token.present?
      refresh_record = RefreshToken.find_by(
        token_digest: RefreshToken.digest(raw_refresh_token),
        company_id: payload["company_id"],
        user_id: payload["sub"]
      )

      refresh_record&.revoke!
    end

    render json: {
      message: "Logout successful"
    }, status: :ok
  rescue JWT::DecodeError
    render json: { error: "Invalid token" },
           status: :unauthorized
  end

  private

  def render_invalid_credentials
    render json: {
      error: "Invalid company or credentials"
    }, status: :unauthorized
  end
end
