class ApplicationController < ActionController::API
  include Pundit::Authorization
  include TenantLoader
  include ApiResponder
  include ErrorHandler
end
