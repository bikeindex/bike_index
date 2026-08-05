# frozen_string_literal: true

module Backfills
  # theft_alert_id and user_phone_id were replaced by the alertable polymorphic pair.
  # UserAlert still reads the old columns as a fallback, so this can run after the deploy
  class UserAlertAlertableJob < ApplicationJob
    include Sidekiq::IterableJob

    sidekiq_options queue: "low_priority", retry: false

    # batch_size has to be passed - the enumerator hands in_batches an explicit `of: nil` without it
    def build_enumerator(cursor:)
      active_record_relations_enumerator(user_alerts, cursor:, batch_size: 1_000)
    end

    # Backfilled rows drop out of the relation, but the cursor moves forward by id, so a resumed
    # run doesn't skip anything
    def each_iteration(batch)
      batch.where.not(theft_alert_id: nil)
        .update_all("alertable_type = 'TheftAlert', alertable_id = theft_alert_id")
      batch.where.not(user_phone_id: nil)
        .update_all("alertable_type = 'UserPhone', alertable_id = user_phone_id")
    end

    # The duplicates predate the uniqueness validation and are inert while alertable_id is blank.
    # Backfilling arms the validation, which would leave the survivor unable to save
    def on_complete
      uniq_kind_alerts.where.not(id: lowest_of_each_group).delete_all
    end

    private

    def uniq_kind_alerts
      UserAlert.where(kind: UserAlert::UNIQ_KINDS).where.not(alertable_id: nil)
    end

    # find_or_build_by returns the lowest id, so the rest are the rows nothing reads
    def lowest_of_each_group
      uniq_kind_alerts.group(:user_id, :kind, :alertable_type, :alertable_id).select("MIN(id)")
    end

    def user_alerts
      base = UserAlert.where(alertable_id: nil)

      base.where.not(theft_alert_id: nil).or(base.where.not(user_phone_id: nil))
    end
  end
end
