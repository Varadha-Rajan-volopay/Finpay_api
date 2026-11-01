require "rails_helper"

RSpec.describe "FinpayAPI smoke test" do
  it "loads the Rails application successfully" do
    expect(Rails.application).to be_present
  end
end
