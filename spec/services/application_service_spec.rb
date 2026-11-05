require "rails_helper"

RSpec.describe ApplicationService do
  describe ".call" do
    it "runs the service and returns a successful result" do
      service_class = Class.new(described_class) do
        def call
          "service completed"
        end
      end

      result = service_class.call

      expect(result).to be_success
      expect(result.value).to eq("service completed")
      expect(result.errors).to be_empty
    end

    it "allows unexpected errors to propagate" do
      service_class = Class.new(described_class) do
        def call
          raise StandardError, "Something went wrong"
        end
      end

      expect do
        service_class.call
      end.to raise_error(StandardError, "Something went wrong")
    end

    it "preserves a result returned by the service" do
      service_class = Class.new(described_class) do
        def call
          ApplicationService::Result.new(
            success: false,
            errors: [ "Operation failed" ]
          )
        end
      end

      result = service_class.call

      expect(result).to be_failure
      expect(result.errors).to eq([ "Operation failed" ])
    end
  end
end
