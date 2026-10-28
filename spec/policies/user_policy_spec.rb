
require "rails_helper"

RSpec.describe UserPolicy do
  let(:company_id) { 10 }
  let(:other_company_id) { 20 }

  def make_user(id:, company_id:, admin: false)
    double(
      "User",
      id: id,
      company_id: company_id,
      admin?: admin
    )
  end

  def make_record(id:, company_id:)
    double(
      "UserRecord",
      id: id,
      company_id: company_id
    )
  end

  describe "authorization" do
    it "allows an admin to view users in the same company" do
      admin = make_user(id: 1, company_id: company_id, admin: true)
      target = make_record(id: 2, company_id: company_id)

      expect(described_class.new(admin, target).show?).to be(true)
    end

    it "allows a member to view their own record" do
      member = make_user(id: 2, company_id: company_id)
      target = make_record(id: 2, company_id: company_id)

      expect(described_class.new(member, target).show?).to be(true)
    end

    it "does not allow a member to view another member" do
      member = make_user(id: 2, company_id: company_id)
      target = make_record(id: 3, company_id: company_id)

      expect(described_class.new(member, target).show?).to be(false)
    end

    it "does not allow access to a user in another company" do
      admin = make_user(id: 1, company_id: company_id, admin: true)
      target = make_record(id: 2, company_id: other_company_id)

      expect(described_class.new(admin, target).show?).to be(false)
    end

    it "allows a member to update their own record" do
      member = make_user(id: 2, company_id: company_id)
      target = make_record(id: 2, company_id: company_id)

      expect(described_class.new(member, target).update?).to be(true)
    end

    it "does not allow a member to update another user's record" do
      member = make_user(id: 2, company_id: company_id)
      target = make_record(id: 3, company_id: company_id)

      expect(described_class.new(member, target).update?).to be(false)
    end

    it "denies actions by default" do
      member = make_user(id: 2, company_id: company_id)
      target = make_record(id: 3, company_id: company_id)
      policy = described_class.new(member, target)

      expect(policy.create?).to be(false)
      expect(policy.destroy?).to be(false)
    end
  end
end
