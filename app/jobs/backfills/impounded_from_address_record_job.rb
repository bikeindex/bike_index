# frozen_string_literal: true

module Backfills
  # A parking notification linked after a default impound location had set address_record never
  # became the impounded-from address. Saving builds it from the notification
  class ImpoundedFromAddressRecordJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      ImpoundRecord.where(impounded_from_address_record_id: nil)
        .where(id: ParkingNotification.where.not(latitude: nil).select(:impound_record_id))
        .find_each do |impound_record|
          impound_record.skip_update = true
          impound_record.save(touch: false)
        end
    end
  end
end
