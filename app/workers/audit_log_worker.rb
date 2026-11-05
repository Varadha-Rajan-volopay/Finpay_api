# frozen_string_literal: true

require "time"

class AuditLogWorker
  include Sidekiq::Job
  include TenantWorker

  sidekiq_options queue: :critical, retry: 5

  def perform(tenant_id, expense_id, actor_id, action, from_state, to_state, event_time)
    with_tenant(tenant_id) do
      ActivityLog.create_or_find_by!(
        expense_id: expense_id,
        actor_id: actor_id,
        action: action,
        from_state: from_state,
        to_state: to_state,
        created_at: Time.iso8601(event_time)
      )
    end
  end
end
