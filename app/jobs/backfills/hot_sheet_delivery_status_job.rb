# frozen_string_literal: true

module Backfills
  # delivery_status became an enum in #2691, which leaves every existing sheet delivery_pending -
  # so a day's delivered sheets look unsent, and the next run mails them again. email_success
  # was the only value the string column ever held
  class HotSheetDeliveryStatusJob < ApplicationJob
    include Sidekiq::IterableJob

    sidekiq_options queue: "low_priority", retry: false

    LEGACY_DELIVERED = "email_success"

    # batch_size has to be passed - the enumerator hands in_batches an explicit `of: nil` without it
    def build_enumerator(cursor:)
      active_record_relations_enumerator(hot_sheets, cursor:, batch_size: 1_000)
    end

    # Updated rows drop out of the relation, but the cursor moves forward by id, so a resumed
    # run doesn't skip anything
    def each_iteration(batch)
      batch.update_all(delivery_status: :delivery_success)
    end

    private

    # A sheet the new code has already written is left alone
    def hot_sheets
      HotSheet.where(delivery_status_legacy: LEGACY_DELIVERED, delivery_status: :delivery_pending)
    end
  end
end
