require "rails_helper"

RSpec.describe "API versioning", type: :request do
  describe "legacy unversioned endpoints" do
    it "returns 404 for the old expenses endpoint" do
      get "/expenses"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for the old expense creation endpoint" do
      post "/expenses"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for the old login endpoint" do
      post "/auth/login"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for the old registration endpoint" do
      post "/auth/register"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for the old refresh endpoint" do
      post "/auth/refresh"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for the old current-user endpoint" do
      get "/auth/me"
      expect(response).to have_http_status(:not_found)
    end
  end
end
