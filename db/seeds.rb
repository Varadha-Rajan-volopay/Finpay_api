# frozen_string_literal: true

# Demo data for FinpayAPI.
# Run with: bin/rails db:seed
#
# Creates two isolated tenants (acme and beta), each with an admin,
# a member, and the standard expense categories. Safe to run repeatedly.

module FinpayDemoSeeds
  DEMO_PASSWORD = "Password@123"

  COMPANIES = [
    {
      name: "Acme Corporation",
      subdomain: "acme",
      users: [
        { email: "admin.acme@example.com", role: :admin },
        { email: "employee.acme@example.com", role: :member }
      ]
    },
    {
      name: "Beta Corporation",
      subdomain: "beta",
      users: [
        { email: "admin.beta@example.com", role: :admin },
        { email: "employee.beta@example.com", role: :member }
      ]
    }
  ].freeze

  CATEGORIES = [
    "Meals",
    "Travel",
    "Office Supplies",
    "Software",
    "Accommodation"
  ].freeze

  def self.run!
    COMPANIES.each { |attributes| seed_company!(attributes) }
    puts "FinpayAPI demo data seeded successfully."
  end

  def self.seed_company!(attributes)
    company = Company.find_by(subdomain: attributes[:subdomain])

    if company
      Apartment::Tenant.switch(company.subdomain) do
        seed_tenant_records!(company, attributes[:users])
      end
      puts "Updated existing tenant: #{company.subdomain}"
    else
      Companies::Provision.call(
        name: attributes[:name],
        subdomain: attributes[:subdomain]
      ) do |provisioned_company|
        seed_tenant_records!(provisioned_company, attributes[:users])
      end
      puts "Created tenant: #{attributes[:subdomain]}"
    end
  ensure
    Apartment::Tenant.reset
  end

  def self.seed_tenant_records!(company, users)
    CATEGORIES.each do |category_name|
      Category.find_or_create_by!(name: category_name)
    end

    users.each do |attributes|
      user = User.find_or_initialize_by(email: attributes[:email])
      user.company_id = company.id
      user.role = attributes[:role]
      user.password = DEMO_PASSWORD
      user.password_confirmation = DEMO_PASSWORD
      user.save!
    end

    puts "  Categories: #{Category.count}"
    puts "  Demo users: #{users.map { |user| user[:email] }.join(', ')}"
    puts "  Meals category_id: #{Category.find_by!(name: 'Meals').id}"
  end
end

FinpayDemoSeeds.run!
