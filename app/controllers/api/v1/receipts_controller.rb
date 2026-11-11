
# frozen_string_literal: true

module Api
  module V1
    class ReceiptsController < ApplicationController
      before_action :set_expense
      before_action :set_receipt, only: :show

      def create
        authorize @expense, :show?

        uploaded_file = params.require(:file)

        storage_key = ReceiptFileStorage.new(
          uploaded_file: uploaded_file,
          tenant_id: current_user.company_id
        ).call

        receipt = @expense.receipts.new(
          file_name: uploaded_file.original_filename,
          content_type: uploaded_file.content_type,
          byte_size: uploaded_file.size,
          storage_key: storage_key,
          ocr_status: "pending",
          company_id: current_user.company_id
        )

        if receipt.save
          render_success(
            data: Api::V1::ReceiptSerializer.new(receipt).serializable_hash,
            status: :created
          )
        else
          ReceiptFileStorage.delete(storage_key)

          render_error(
            code: "validation_failed",
            message: "Receipt could not be uploaded",
            details: receipt.errors.full_messages
          )
        end
      rescue ArgumentError => e
        render_error(
          code: "invalid_receipt",
          message: e.message,
          status: :unprocessable_entity
        )
      end

      def show
        authorize @expense, :show?

        render_success(
          data: Api::V1::ReceiptSerializer.new(@receipt).serializable_hash
        )
      end

      private

      def set_expense
        @expense = policy_scope(Expense).find(params[:expense_id])
      end

      def set_receipt
        @receipt = @expense.receipts.find(params[:id])
      end
    end
  end
end
