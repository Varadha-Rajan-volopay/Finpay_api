# frozen_string_literal: true

module Errors
  class Base < StandardError
    attr_reader :details

    def initialize(message = nil, details: [])
      super(message)
      @details = details
    end

    def status
      :unprocessable_entity
    end

    def code
      self.class.name.demodulize.underscore
    end
  end

  class Forbidden < Base
    def status
      :forbidden
    end
  end

  class TenantNotFound < Base
    def status
      :unauthorized
    end
  end

  class InvalidTransition < Base
    def status
      :unprocessable_entity
    end
  end

  class IdempotencyConflict < Base
    def status
      :conflict
    end
  end
end
