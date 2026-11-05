require "rails_helper"

RSpec.describe "Health endpoint", type: :request do
  describe "GET /up" do
    it "returns a successful health response" do
      get "/up"

      expect(response).to have_http_status(:ok)
    end
  end
end
