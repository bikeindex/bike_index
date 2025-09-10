# frozen_string_literal: true

class Backfills::AddressRecordForceGeocodeJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: false

  def perform(id)
    address_record = AddressRecord.find(id)

    address_record.update(force_geocoding: true)
  end
end
