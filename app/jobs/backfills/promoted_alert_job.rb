# frozen_string_literal: true

module Backfills
  # Copy theft_alerts into promoted_alerts verbatim - same ids, same created_at and updated_at,
  # same everything else - so a row can be read through either model while TheftAlert is removed.
  # Re-running only copies what isn't there yet.
  #
  # Run this once the deploy has finished rolling out, not during it: repointing the polymorphic
  # types is only safe when every process can resolve PromotedAlert.
  class PromotedAlertJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      copy_alerts
      advance_id_sequence
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

    # Forward only - CreatePromotedAlerts parked the sequence past the ids this copies, and
    # winding it back would put a later alert on a collision course with one of them
    def advance_id_sequence
      connection.execute(<<~SQL)
        SELECT setval('promoted_alerts_id_seq', GREATEST(
          (SELECT last_value FROM promoted_alerts_id_seq),
          (SELECT COALESCE(MAX(id), 0) + 1 FROM promoted_alerts)
        ), false)
      SQL
    end
  end
end
