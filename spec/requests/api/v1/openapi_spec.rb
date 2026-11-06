# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "FinpayAPI V1", type: :request do

  before do
    self.use_transactional_tests = false if
      RSpec.current_example.metadata[:full_description].include?("Register a company")
  end
  let(:body) { {} }
  let(:id) { 1 }
  let(:Authorization) { nil }
  let(:"Idempotency-Key") { "openapi-test-key" }

  path "/api/v1/auth/login" do
    post "Login" do
      tags "Authentication"
      operationId "login"
      consumes "application/json"
      produces "application/json"
      security []

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: %w[company user],
        properties: {
          company: {
            type: :object,
            required: ["subdomain"],
            properties: {
              subdomain: { type: :string, example: "acme" }
            }
          },
          user: {
            type: :object,
            required: %w[email password],
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password }
            }
          }
        }
      }

      response "200", "Login successful" do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 access_token: { type: :string },
                 refresh_token: { type: :string },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     company_id: { type: :integer },
                     role: { type: :string }
                   }
                 }
               }
      end

      response "401", "Invalid company or credentials" do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }
        run_test!
      end

      response "429", "Too many login attempts" do
        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     code: { type: :string },
                     message: { type: :string },
                     details: { type: :array, items: {} }
                   }
                 }
               }
      end
    end
  end

  path "/api/v1/auth/logout" do
    delete "Logout" do
      tags "Authentication"
      operationId "logout"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "200", "Logout successful" do
        schema type: :object,
               properties: {
                 message: { type: :string }
               }
      end

      response "401", "Missing or invalid token" do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }
        run_test!
      end
    end
  end

  path "/api/v1/auth/register" do
    post "Register a company and its admin user" do
      tags "Authentication"
      operationId "register"
      consumes "application/json"
      produces "application/json"
      security []

      let(:body) do
        {
          company: {
          name: "Finpay Test Company",
          subdomain: "finpaytest#{SecureRandom.hex(3)}"
          },
          user: {
          email: "admin@example.com",
          password: "password123",
          password_confirmation: "password123"
          }
        }
      end

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: %w[company user],
        properties: {
          company: {
            type: :object,
            required: %w[name subdomain],
            properties: {
              name: { type: :string, example: "Finpay Test Company" },
              subdomain: { type: :string, example: "finpaytest" }
            }
          },
          user: {
            type: :object,
            required: %w[email password password_confirmation],
            properties: {
              email: { type: :string, format: :email },
              password: { type: :string, format: :password },
              password_confirmation: { type: :string, format: :password }
            }
          }
        }
      }

      response "201", "Company and admin user registered successfully" do
        schema type: :object,
               properties: {
                message: { type: :string },
                company: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    name: { type: :string },
                    subdomain: { type: :string }
                  }
                },
                user: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    email: { type: :string },
                    role: { type: :string }
                  }
                }
              }
        run_test!
      end

      response "409", "Company subdomain already registered" do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }
      end

      response "422", "Invalid registration data" do
        let(:body) do
          {
            company: {
              name: "",
              subdomain: "invalid-test"
            },
            user: {
              email: "invalid-email",
              password: "password123",
              password_confirmation: "password123"
            }
          }
        end

        schema type: :object,
                properties: {
                  errors: {
                    type: :array,
                    items: { type: :string }
                  }
                }

        run_test!
      end

      response "429", "Too many registration attempts" do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }
      end
    end
  end

  path "/api/v1/auth/refresh" do
    post "Refresh access and refresh tokens" do
      tags "Authentication"
      operationId "refreshToken"
      consumes "application/json"
      produces "application/json"
      security []

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: ["refresh_token"],
        properties: {
          refresh_token: { type: :string }
        }
      }

      response "200", "Tokens refreshed successfully" do
        schema type: :object,
               properties: {
                 access_token: { type: :string },
                 refresh_token: { type: :string },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     company_id: { type: :integer },
                     role: { type: :string }
                   }
                 }
               }
      end

      response "401", "Invalid, expired, or revoked refresh token" do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }
        run_test!
      end
    end
  end

  path "/api/v1/auth/me" do
    get "Get the authenticated user" do
      tags "Authentication"
      operationId "currentUser"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "200", "Current user returned" do
        schema type: :object,
               properties: {
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     company_id: { type: :integer },
                     role: { type: :string }
                   }
                 }
               }
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "User is not authorized" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end
  end

  path "/api/v1/expenses" do
    get "List expenses" do
      tags "Expenses"
      operationId "listExpenses"
      produces "application/json"
      security [{ bearerAuth: [] }]

      parameter name: :category_id, in: :query, type: :integer, required: false
      parameter name: :status, in: :query, type: :string, required: false
      parameter name: :from, in: :query, type: :string, format: :date, required: false
      parameter name: :to, in: :query, type: :string, format: :date, required: false
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per, in: :query, type: :integer, required: false,
                description: "Results per page. Default 20, maximum 100."
      parameter name: :pagination, in: :query, type: :string, required: false,
                enum: %w[offset keyset]
      parameter name: :cursor, in: :query, type: :string, required: false

      response "200", "Expenses returned" do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: { "$ref" => "#/components/schemas/Expense" }
                 },
                 meta: {
                   type: :object,
                   description: "Offset or keyset pagination metadata."
                 }
               }
      end

      response "400", "Invalid pagination parameters" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Access forbidden" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Invalid filter parameters" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end

    post "Create an expense" do
      tags "Expenses"
      operationId "createExpense"
      consumes "application/json"
      produces "application/json"
      security [{ bearerAuth: [] }]

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: ["expense"],
        properties: {
          expense: {
            type: :object,
            required: %w[title category_id amount_cents currency incurred_on],
            properties: {
              title: { type: :string },
              category_id: { type: :integer },
              amount_cents: { type: :integer, minimum: 1 },
              currency: { type: :string, example: "INR" },
              incurred_on: { type: :string, format: :date },
              notes: { type: :string }
            }
          }
        }
      }

      response "201", "Expense created" do
        schema type: :object,
               properties: {
                 data: { "$ref" => "#/components/schemas/Expense" }
               }
      end

      response "400", "Invalid request body" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Access forbidden" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Expense validation failed" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end
  end

  path "/api/v1/expenses/{id}" do
    parameter name: :id, in: :path, type: :integer, required: true

    get "Get an expense" do
      tags "Expenses"
      operationId "getExpense"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "200", "Expense returned" do
        schema type: :object,
               properties: {
                 data: { "$ref" => "#/components/schemas/Expense" }
               }
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Access forbidden" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end

    patch "Update an expense" do
      tags "Expenses"
      operationId "updateExpense"
      consumes "application/json"
      produces "application/json"
      security [{ bearerAuth: [] }]

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: ["expense"],
        properties: {
          expense: {
            type: :object,
            properties: {
              title: { type: :string },
              category_id: { type: :integer },
              amount_cents: { type: :integer, minimum: 1 },
              currency: { type: :string },
              incurred_on: { type: :string, format: :date },
              notes: { type: :string }
            }
          }
        }
      }

      response "200", "Expense updated" do
        schema type: :object,
               properties: {
                 data: { "$ref" => "#/components/schemas/Expense" }
               }
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Access forbidden" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Expense validation failed" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end

    put "Update an expense using PUT" do
      tags "Expenses"
      operationId "replaceExpense"
      consumes "application/json"
      produces "application/json"
      security [{ bearerAuth: [] }]

      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        required: ["expense"],
        properties: {
          expense: {
            type: :object,
            properties: {
              title: { type: :string },
              category_id: { type: :integer },
              amount_cents: { type: :integer },
              currency: { type: :string },
              incurred_on: { type: :string, format: :date },
              notes: { type: :string }
            }
          }
        }
      }

      response "200", "Expense updated" do
        schema type: :object,
               properties: {
                 data: { "$ref" => "#/components/schemas/Expense" }
               }
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Access forbidden" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Expense validation failed" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end

    delete "Delete an expense" do
      tags "Expenses"
      operationId "deleteExpense"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "204", "Expense deletion completed" do
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Access forbidden" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Expense could not be deleted" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end
  end

  path "/api/v1/expenses/{id}/approve" do
    parameter name: :id, in: :path, type: :integer, required: true
    parameter name: "Idempotency-Key", in: :header, type: :string,
              required: true

    post "Approve an expense" do
      tags "Expense Workflow"
      operationId "approveExpense"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "200", "Expense approved" do
        schema type: :object
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Only an authorized admin can approve" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Workflow transition failed" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end
  end

  path "/api/v1/expenses/{id}/reject" do
    parameter name: :id, in: :path, type: :integer, required: true
    parameter name: "Idempotency-Key", in: :header, type: :string,
              required: true

    post "Reject an expense" do
      tags "Expense Workflow"
      operationId "rejectExpense"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "200", "Expense rejected" do
        schema type: :object
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Only an authorized admin can reject" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Workflow transition failed" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end
  end

  path "/api/v1/expenses/{id}/reimburse" do
    parameter name: :id, in: :path, type: :integer, required: true
    parameter name: "Idempotency-Key", in: :header, type: :string,
              required: true,
              description: "Unique key used to make reimbursement requests repeat-safe."

    post "Reimburse an expense" do
      tags "Expense Workflow"
      operationId "reimburseExpense"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "200", "Expense reimbursed" do
        schema type: :object
      end

      response "400", "Invalid idempotency key" do
        schema type: :object
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Only an authorized admin can reimburse" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Reimbursement failed" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end
  end

  path "/api/v1/expenses/{id}/archive" do
    parameter name: :id, in: :path, type: :integer, required: true

    post "Archive an expense" do
      tags "Expense Workflow"
      operationId "archiveExpense"
      produces "application/json"
      security [{ bearerAuth: [] }]

      response "200", "Expense archived" do
        schema type: :object,
               properties: {
                 data: { "$ref" => "#/components/schemas/Expense" }
               }
      end

      response "401", "Authentication required" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        run_test!
      end

      response "403", "Only an authorized admin can archive" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "404", "Expense not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "422", "Workflow transition failed" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end

      response "429", "Rate limit exceeded" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
      end
    end
  end
end
