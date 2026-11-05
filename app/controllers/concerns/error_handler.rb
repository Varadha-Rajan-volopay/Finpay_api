# frozen_string_literal: true

module ErrorHandler
  extend ActiveSupport::Concern

  included do
    # Keep the generic handler before specific handlers.
    # Rails gives more specific registered handlers priority.
    rescue_from StandardError, with: :handle_internal_error

    rescue_from Errors::Base, with: :handle_application_error
    rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_bad_request
    rescue_from ActionController::BadRequest, with: :handle_bad_request
    rescue_from ActiveRecord::RecordNotUnique, with: :handle_conflict
    rescue_from ActiveRecord::InvalidForeignKey, with: :handle_conflict
    rescue_from AASM::InvalidTransition, with: :handle_invalid_transition
  end

  private

  def handle_application_error(exception)
    render_error(
      code: exception.code,
      message: exception.message,
      details: exception.details,
      status: exception.status
    )
  end

  def handle_forbidden(_exception)
    render_error(
      code: "forbidden",
      message: "You are not authorized to perform this action",
      status: :forbidden
    )
  end

  def handle_not_found(_exception)
    render_error(
      code: "not_found",
      message: "Record not found",
      status: :not_found
    )
  end

  def handle_record_invalid(exception)
    render_error(
      code: "validation_failed",
      message: "Record is invalid",
      details: exception.record.errors.full_messages,
      status: :unprocessable_entity
    )
  end

  def handle_bad_request(_exception)
    render_error(
      code: "bad_request",
      message: "The request is invalid",
      status: :bad_request
    )
  end

  def handle_conflict(_exception)
    render_error(
      code: "conflict",
      message: "The request conflicts with existing data",
      status: :conflict
    )
  end

  def handle_invalid_transition(_exception)
    render_error(
      code: "invalid_transition",
      message: "This workflow transition is not allowed",
      status: :unprocessable_entity
    )
  end

  def handle_internal_error(exception)
    Rails.logger.error(
      "Unhandled #{exception.class}: #{exception.message}\n" \
      "#{exception.backtrace&.first(10)&.join("\n")}"
    )

    render_error(
      code: "internal_server_error",
      message: "An unexpected error occurred",
      status: :internal_server_error
    )
  end
end
