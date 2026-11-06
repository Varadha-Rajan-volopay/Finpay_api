# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "FinpayAPI",
        version: "v1",
        description: "Version 1 of the Finpay expense management API."
      },
      servers: [
        {
          url: ENV.fetch("API_BASE_URL", "http://localhost:3000")
        }
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: "JWT"
          }
        },
        schemas: {
          ErrorResponse: {
            type: :object,
            properties: {
              error: {
                type: :object,
                properties: {
                  code: { type: :string },
                  message: { type: :string },
                  details: {
                    type: :array,
                    items: {}
                  }
                },
                required: %w[code message details]
              }
            },
            required: ["error"]
          }
        },
        Expense: {
          type: :object,
          properties: {
            id: { type: :integer },
            user_id: { type: :integer },
            category_id: { type: :integer },
            title: { type: :string },
            amount_cents: { type: :integer },
            currency: { type: :string, example: "INR" },
            status: {
              type: :string,
              enum: %w[pending approved rejected reimbursed archived]
            },
            incurred_on: { type: :string, format: :date },
            reference_number: { type: :string, nullable: true },
            reimbursed_at: {
              type: :string,
              format: "date-time",
              nullable: true
            },
            created_at: { type: :string, format: "date-time" },
            updated_at: { type: :string, format: "date-time" },
            amount_display: { type: :string, example: "2500.00" },
            category_name: { type: :string }
          }
        }
      },
      security: [
        { bearerAuth: [] }
      ],
      paths: {}
    }
  }

  config.openapi_format = :yaml
end
