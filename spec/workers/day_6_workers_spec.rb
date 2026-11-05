
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
        event_time = Time.current.iso8601(6)

        args = [
          company.id,
          expense.id,
          member.id,
          "create",
          "new",
          "pending",
          event_time
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

    it "logs and skips when the tenant does not exist" do
      original_tenant = Apartment::Tenant.current

      expect(Rails.logger).to receive(:warn).with(
        "TenantWorker: Company not found for tenant_id=-1; skipping job"
      )

      expect {
        described_class.new.perform(
          -1,
          1,
          1,
          "create",
          "new",
          "pending",
          Time.current.iso8601(6)

        )
      }.not_to raise_error

      expect(Apartment::Tenant.current).to eq(original_tenant)
    end

    it "re-raises an audit logging error so Sidekiq can retry" do
      with_worker_tenant do |company, member, _admin, expense|
        allow(ActivityLog).to receive(:create_or_find_by!)
          .and_raise(StandardError, "database unavailable")

        expect {
          described_class.new.perform(
            company.id,
            expense.id,
            member.id,
            "create",
            "new",
            "pending",
            Time.current.iso8601(6)
          )
        }.to raise_error(StandardError, "database unavailable")
      end
    end

    it "allows legitimate repeated audit events with different timestamps" do
      with_worker_tenant do |company, member, _admin, expense|
        base_args = [
          company.id,
          expense.id,
          member.id,
          "create",
          "new",
          "pending"
        ]

        first_timestamp = 1.minute.ago.iso8601(6)
        second_timestamp = Time.current.iso8601(6)

        expect {
          described_class.new.perform(*base_args, first_timestamp)
          described_class.new.perform(*base_args, second_timestamp)
        }.to change {
          Apartment::Tenant.switch(company.subdomain) do
            ActivityLog.count
          end
        }.by(2)
      end
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

    it "skips processing when the receipt does not exist" do
      with_worker_tenant do |company, _member, _admin, _expense|
        expect(Rails.logger).to receive(:warn).with(
          "ReceiptProcessorWorker: Receipt not found for receipt_id=999999; skipping job"
        )

        expect {
          described_class.new.perform(company.id, 999999)
        }.not_to raise_error
      end
    end

    it "does not mark a completed receipt as failed" do
      with_worker_tenant do |company, _member, _admin, expense|
        receipt = create(:receipt, expense: expense, ocr_status: "done")

        described_class.mark_failed(company.id, receipt.id)

        Apartment::Tenant.switch(company.subdomain) do
          expect(Receipt.find(receipt.id).ocr_status).to eq("done")
        end
      end
    end

    it "re-raises a processing error without immediately marking the receipt failed" do
      with_worker_tenant do |company, _member, _admin, expense|
        receipt = create(:receipt, expense: expense)


        allow_any_instance_of(Receipt)
          .to receive(:update!)
          .and_call_original

        allow_any_instance_of(Receipt)
          .to receive(:update!)
          .with(ocr_text: anything, ocr_status: "done")
          .and_raise(StandardError, "OCR failure")

        expect {
          described_class.new.perform(company.id, receipt.id)
        }.to raise_error(StandardError, "OCR failure")

        Apartment::Tenant.switch(company.subdomain) do
          expect(Receipt.find(receipt.id).ocr_status).to eq("processing")
        end
      end
    end

    it "marks the receipt failed after Sidekiq retries are exhausted" do
      with_worker_tenant do |company, _member, _admin, expense|
        receipt = create(:receipt, expense: expense)

        described_class.mark_failed(company.id, receipt.id)

        Apartment::Tenant.switch(company.subdomain) do
          expect(Receipt.find(receipt.id).ocr_status).to eq("failed")
        end
      end
    end
  end


  describe OverdueReminderWorker do
    it "logs a tenant processing error without crashing the job" do
      with_worker_tenant do |company, _member, _admin, _expense|
        allow(Company).to receive(:find_each).and_yield(company)

        allow(Expense).to receive(:pending)
          .and_raise(StandardError, "query failed")

        expect(Rails.logger).to receive(:error).with(
          "OverdueReminderWorker failed for company #{company.id}: StandardError: query failed"
        )

        expect {
          described_class.new.perform
        }.not_to raise_error
      end
    end

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
          "pending",
          kind_of(String)

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
      with_worker_tenant do |_company, _member, _admin, expense|
        expect(ReceiptProcessorWorker).not_to receive(:perform_async)

        Apartment::Tenant.switch(Apartment::Tenant.current) do
          Receipt.transaction do
            create(:receipt, expense: expense)

            raise ActiveRecord::Rollback
          end
        end
      end
    end
  end
end
