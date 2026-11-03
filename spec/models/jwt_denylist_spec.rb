require "rails_helper"

RSpec.describe JwtDenylist, type: :model do
  it "includes the Devise JWT denylist revocation strategy" do
    expect(
      described_class.ancestors
    ).to include(Devise::JWT::RevocationStrategies::Denylist)
  end
end
