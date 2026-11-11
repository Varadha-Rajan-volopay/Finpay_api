
module Api
  module V1
    class CategoriesController < ApplicationController
      before_action :require_admin!, only: :create

      def index
        categories = Category.order(:id)

        render json: {
          categories: categories.map do |category|
            {
              id: category.id,
              name: category.name
            }
          end
        }, status: :ok
      end

      def create
        category = Category.new(category_params)

        if category.save
          render json: {
            message: "Category created successfully",
            category: {
              id: category.id,
              name: category.name
            }
          }, status: :created
        else
          render json: {
            errors: category.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def require_admin!
        return if current_user.admin?

        render json: {
          error: "Only admins can create categories"
        }, status: :forbidden
      end

      def category_params
        params.require(:category).permit(:name)
      end
    end
  end
end
