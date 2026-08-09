# frozen_string_literal: true

module Backfills
  # Copy theft_alerts into promoted_alerts verbatim - same ids, same created_at and updated_at,
  # same everything else - so a row can be read through either model while TheftAlert is removed.
  # Re-running only copies what isn't there yet.
  class PromotedAlertJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      copy_alerts
      # New alerts are PromotedAlerts now, so the sequence has to clear the copied ids
      connection.execute("SELECT setval('promoted_alerts_id_seq', " \
        "COALESCE((SELECT MAX(id) FROM promoted_alerts), 0) + 1, false)")
      # Only after the alerts exist, or the polymorphic associations point at nothing
      Notification.where(notifiable_type: "TheftAlert").update_all(notifiable_type: "PromotedAlert")
      UserAlert.where(alertable_type: "TheftAlert").update_all(alertable_type: "PromotedAlert")
    end

    private

    def connection
      PromotedAlert.connection
    end

    def copy_alerts
      columns = TheftAlert.column_names.map { connection.quote_column_name(it) }.join(", ")
      connection.execute("INSERT INTO promoted_alerts (#{columns}) " \
        "SELECT #{columns} FROM theft_alerts ON CONFLICT (id) DO NOTHING")
    end
  end
end
