# frozen_string_literal: true

class Backfills::AddressRecordsForBikesJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority"

  class << self
    def iterable_scope
      Bike.where(address_record_id: nil).where.not(city: nil, street: nil)
    end

    def build_or_create_for(bike, country_id: nil)
      return bike.address_record if bike.address_record.present?

      existing_address_record = AddressRecord.where(kind: :bike, bike_id: bike.id).order(:id).last
      if existing_address_record.present?
        bike.update(address_record: existing_address_record)
        existing_address_record
      end

      bike.address_record = AddressRecord.new(bike_id: bike.id, kind: :bike, country_id:)
      bike.address_record.attributes = AddressRecord.attrs_from_legacy(bike)
      bike.save
      bike.address_record.skip_geocoding = false
      bike.address_record
    end
  end

  def build_enumerator(cursor:)
    return if skip_job?

    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(address_record)
    self.class.build_or_create_for(address_record)
  end
end
