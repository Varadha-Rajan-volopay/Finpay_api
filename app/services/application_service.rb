# frozen_string_literal: true

class ApplicationService
  class Result
    attr_reader :value, :errors

    def initialize(success:, value: nil, errors: [])
      @success = success
      @value = value
      @errors = errors
    end

    def success?
      @success
    end

    def failure?
      !success?
    end
  end

  def self.call(...)
    result = new(...).call

    return result if result.is_a?(Result)

    Result.new(success: true, value: result)
  end
end
