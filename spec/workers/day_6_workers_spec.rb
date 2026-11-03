
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Day 6 background workers" do
  self.use_transactional_tests = false

  def with_worker_tenant
    subdomain = "worker#{SecureRandom.hex(4)}"

    Companies::Provision.call(
      name: "Worker Test Company",
      subdomain: subdomain
    ) do |company|
      # Companies::Provision already switches into this tenant.
      member = create(:user, company: company, role: :member)
      admin = create(:user, company: company, role: :admin)
      category = create(:category)

      expense = create(
        :expense,
        user: member,
        category: category,
        status: "pending"
      )

      yield company, member, admin, expense
    end
  ensure
    Apartment::Tenant.reset

    if subdomain && ActiveRecord::Base.connection.schema_exists?(subdomain)
      Apartment::Tenant.drop(subdomain)
    end

    Company.find_by(subdomain: subdomain)&.delete if subdomain
  end

  describe AuditLogWorker do
    it "creates only one audit log when the job runs twice" do
      with_worker_tenant do |company, member, _admin, expense|
        args = [
          company.id,
          expense.id,
          member.id,
          "create",
          "new",
          "pending"
        ]

        expect {
          described_class.new.perform(*args)
          described_class.new.perform(*args)
        }.to change {
          Apartment::Tenant.switch(company.subdomain) do
            ActivityLog.count
          end
        }.by(1)
      end
    end

    it "raises when the tenant does not exist and resets tenant context" do
      original_tenant = Apartment::Tenant.current

      expect {
        described_class.new.perform(
          -1,
          1,
          1,
          "create",
          "new",
          "pending"
        )
      }.to raise_error(ActiveRecord::RecordNotFound)

      expect(Apartment::Tenant.current).to eq(original_tenant)
    end
  end

  describe ReceiptProcessorWorker do
    it "processes a receipt and skips it when run again" do
      with_worker_tenant do |company, _member, _admin, expense|
        receipt = create(:receipt, expense: expense)

        expect {
          described_class.new.perform(company.id, receipt.id)
          described_class.new.perform(company.id, receipt.id)
        }.to change {
          Apartment::Tenant.switch(company.subdomain) do
            Receipt.find(receipt.id).ocr_status
          end
        }.from("pending").to("done")

        Apartment::Tenant.switch(company.subdomain) do
          processed_receipt = Receipt.find(receipt.id)

          expect(processed_receipt.ocr_text).to eq(
            "Fake OCR output for #{processed_receipt.file_name}"
          )
        end
      end
    end

    it "marks the receipt failed and re-raises a processing error" do
      with_worker_tenant do |company, _member, _admin, expense|
        receipt = create(:receipt, expense: expense)
        update_calls = 0

        allow_any_instance_of(Receipt)
          .to receive(:update!)
          .and_wrap_original do |original, *args, **kwargs|
            update_calls += 1

            raise StandardError, "OCR failure" if update_calls == 2

            original.call(*args, **kwargs)
          end

        expect {
          described_class.new.perform(company.id, receipt.id)
        }.to raise_error(StandardError, "OCR failure")

        Apartment::Tenant.switch(company.subdomain) do
          expect(Receipt.find(receipt.id).ocr_status).to eq("failed")
        end
      end
    end
  end

  describe OverdueReminderWorker do
    it "creates one reminder per overdue expense per day" do
      with_worker_tenant do |company, _member, _admin, expense|
        overdue_days = Rails.configuration.x.expense_overdue_days

        expense.update!(
          incurred_on: Date.current - (overdue_days + 1).days
        )

        recent_expense = create(
          :expense,
          user: expense.user,
          category: expense.category,
          incurred_on: Date.current
        )

        # Restrict this spec to the tenant it provisions.
        allow(Company).to receive(:find_each).and_yield(company)

        expect {
          described_class.new.perform
          described_class.new.perform
        }.to change {
          Apartment::Tenant.switch(company.subdomain) do
            OverdueReminder.where(expense_id: expense.id).count
          end
        }.by(1)

        Apartment::Tenant.switch(company.subdomain) do
          expect(
            OverdueReminder.where(expense_id: recent_expense.id).count
          ).to eq(0)
        end
      end
    end
  end

  describe "after-commit callbacks" do
    it "enqueues expense creation audit only after commit" do
      with_worker_tenant do |company, member, _admin, expense|
        expect(AuditLogWorker).to receive(:perform_async).with(
          company.id,
          anything,
          member.id,
          "create",
          "new",
          "pending"
        )

        # The expense passed into the helper is already committed.
        # Create another expense to test the creation callback.
        Apartment::Tenant.switch(company.subdomain) do
          create(
            :expense,
            user: member,
            category: expense.category
          )
        end
      end
    end

    it "does not enqueue expense creation audit on rollback" do
      with_worker_tenant do |company, member, _admin, expense|
        expect(AuditLogWorker).not_to receive(:perform_async)

        Apartment::Tenant.switch(company.subdomain) do
          Expense.transaction do
            create(
              :expense,
              user: member,
              category: expense.category
            )

            raise ActiveRecord::Rollback
          end
        end
      end
    end

    it "does not enqueue receipt processing on rollback" do
      with_worker_tenant do |company, _member, _admin, expense|
        expect(ReceiptProcessorWorker).not_to receive(:perform_async)

        Apartment::Tenant.switch(company.subdomain) do
          Receipt.transaction do
            create(:receipt, expense: expense)

            raise ActiveRecord::Rollback
          end
        end
      end
    end
  end
end
