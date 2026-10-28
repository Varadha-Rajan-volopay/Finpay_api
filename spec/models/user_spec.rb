
require "rails_helper"

RSpec.describe User, type: :model do
  describe "JWT identifier" do
    let(:user) do
      Class.new do
        attr_accessor :jti

        def generate_jti
          self.jti ||= SecureRandom.uuid
        end
      end.new
    end

    it "generates a jti when the identifier is missing" do
      user.jti = nil

      user.generate_jti

      expect(user.jti).to be_present
      expect(user.jti).to match(
        /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      )
    end

    it "does not replace an existing jti" do
      existing_jti = SecureRandom.uuid
      user.jti = existing_jti

      user.generate_jti

      expect(user.jti).to eq(existing_jti)
    end
  end
end
