
# frozen_string_literal: true

module Api
  module V1
    class EmployeesController < ApplicationController
      def create
        authorize User, :create?

        employee = User.new(employee_params)
        employee.company = current_user.company
        employee.role = :member

        if employee.save
          render_success(
            data: {
              id: employee.id,
              email: employee.email,
              role: employee.role,
              company_id: employee.company_id
            },
            status: :created
          )
        else
          render_error(
            code: "validation_failed",
            message: "Employee could not be created",
            details: employee.errors.full_messages
          )
        end
      end

      private

      def employee_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation
        )
      end
    end
  end
end
