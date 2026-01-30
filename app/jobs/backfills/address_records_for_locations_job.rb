# frozen_string_literal: true

class Backfills::AddressRecordsForLocationsJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority", retry: false

  class << self
    def iterable_scope
      Location.where(address_record_id: nil).where.not(city: nil)
        .or(Location.where(address_record_id: nil).where.not(street: nil))
    end

    def build_or_create_for(location)
      return location.address_record if location.address_record?

      existing_address_record = AddressRecord.where(kind: :organization, organization_id: location.organization_id)
        .find_by(street: location.street, city: location.city)
      if existing_address_record.present? && existing_address_record.internal_address_attrs == AddressRecord.new(AddressRecord.attrs_from_legacy(location)).internal_address_attrs
        location.update(address_record: existing_address_record)
        return existing_address_record
      end

      location.address_record = AddressRecord.new(kind: :organization, organization_id: location.organization_id)
      location.address_record.attributes = AddressRecord.attrs_from_legacy(location)
      location.save
      location.address_record
    end
  end

  def build_enumerator(cursor:)
    return if skip_job?

    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(location)
    self.class.build_or_create_for(location)
  end
end
