
require "rails_helper"

RSpec.describe ActivityLog do
  self.use_transactional_tests = false
  def with_activity_log
    subdomain = "activity_log_#{SecureRandom.hex(4)}"

    Companies::Provision.call(
      name: "Activity Log Test Company",
      subdomain: subdomain
    ) do |company|
      employee = create(:user, company: company, role: :member)
      admin = create(:user, company: company, role: :admin)
      category = create(:category)

      expense = create(
        :expense,
        user: employee,
        category: category,
        status: "pending"
      )

      log = described_class.create!(
        expense: expense,
        actor: admin,
        action: "approve",
        from_state: "pending",
        to_state: "approved"
      )

      yield log, expense, admin
    end
  ensure
    Apartment::Tenant.reset

    if subdomain && ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end
  end

  describe "associations" do
    it "belongs to an expense" do
      with_activity_log do |log, expense, _admin|
        expect(log.expense).to eq(expense)
      end
    end

    it "belongs to an actor" do
      with_activity_log do |log, _expense, admin|
        expect(log.actor).to eq(admin)
      end
    end
  end

  describe "validations" do
    it "requires an action" do
      with_activity_log do |log, _expense, _admin|
        log.action = nil

        expect(log).not_to be_valid
        expect(log.errors[:action]).to include("can't be blank")
      end
    end

    it "requires a from_state" do
      with_activity_log do |log, _expense, _admin|
        log.from_state = nil

        expect(log).not_to be_valid
        expect(log.errors[:from_state]).to include("can't be blank")
      end
    end

    it "requires a to_state" do
      with_activity_log do |log, _expense, _admin|
        log.to_state = nil

        expect(log).not_to be_valid
        expect(log.errors[:to_state]).to include("can't be blank")
      end
    end
  end
end
