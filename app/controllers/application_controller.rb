class ApplicationController < ActionController::API
    include Pundit::Authorization
    include TenantLoader
end
