# frozen_string_literal: true

module ApiResponder
  extend ActiveSupport::Concern

  def render_success(data:, status: :ok, meta: nil)
    response_body = { data: data }
    response_body[:meta] = meta unless meta.nil?

    render json: response_body, status: status
  end

  def render_error(code:, message:, details: [], status: :unprocessable_entity)
    render json: {
      error: {
        code: code,
        message: message,
        details: details
      }
    }, status: status
  end
end
