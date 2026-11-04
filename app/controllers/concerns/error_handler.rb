# frozen_string_literal: true

module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from Errors::Base, with: :handle_application_error
    rescue_from Pundit::NotAuthorizedError, with: :handle_forbidden
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
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

  def handle_invalid_transition(_exception)
    render_error(
      code: "invalid_transition",
      message: "This workflow transition is not allowed",
      status: :unprocessable_entity
    )
  end
end
