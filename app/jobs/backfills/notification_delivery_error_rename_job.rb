# frozen_string_literal: true

module Backfills
  # delivery_error holds the class name postmark raised. postmark 1.23 renamed
  # InvalidEmailAddressError, so rows written before the 1.25.1 bump in #2961 carry the old name
  class NotificationDeliveryErrorRenameJob < ApplicationJob
    include Sidekiq::IterableJob

    sidekiq_options queue: "low_priority", retry: false

    LEGACY_NAME = "Postmark::InvalidEmailAddressError"
    CURRENT_NAME = "Postmark::InvalidEmailRequestError"

    # batch_size has to be passed - the enumerator hands in_batches an explicit `of: nil` without it
    def build_enumerator(cursor:)
      active_record_relations_enumerator(notifications, cursor:, batch_size: 1_000)
    end

    # Renamed rows drop out of the relation, but the cursor moves forward by id, so a resumed
    # run doesn't skip anything
    def each_iteration(batch)
      batch.update_all(delivery_error: CURRENT_NAME)
    end

    private

    def notifications
      Notification.where(delivery_error: LEGACY_NAME)
    end
  end
end
