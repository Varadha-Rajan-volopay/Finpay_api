require "rails_helper"
require Rails.root.join(
  "db/tenant_migrate/20261105110000_replace_reimbursed_at_index_with_partial_index"
)

RSpec.describe ReplaceReimbursedAtIndexWithPartialIndex do
  self.use_transactional_tests = false

  let(:company) do
    create(:company, subdomain: "partial_index_#{SecureRandom.hex(3)}")
  end

  after do
    Apartment::Tenant.reset

    if company&.persisted?
      if ActiveRecord::Base.connection.schema_exists?(company.subdomain)
        Apartment::Tenant.drop(company.subdomain)
      end

      company.delete
    end
  end

  it "keeps only a partial index on reimbursed_at and can safely rerun" do
    connection = ActiveRecord::Base.connection

    connection.execute(
      "CREATE SCHEMA #{connection.quote_table_name(company.subdomain)}"
    )

    Companies::TenantMigration.run!(company.subdomain)

    Apartment::Tenant.switch(company.subdomain) do
      migration = described_class.new

      migration.up
      migration.up

      indexes = connection.indexes("expenses")

      partial_index = indexes.find do |index|
        index.name == "index_expenses_on_reimbursed_at_not_null"
      end

      expect(partial_index).to be_present
      expect(partial_index.where).to eq("(reimbursed_at IS NOT NULL)")
      expect(
        indexes.map(&:name)
      ).not_to include("index_expenses_on_reimbursed_at")
    end
  end
end
