# frozen_string_literal: true

class Backfills::AddressRecordsForImpoundRecordsJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority", retry: false

  class << self
    def iterable_scope
      ImpoundRecord.where(address_record_id: nil).where.not(city: nil)
        .or(ImpoundRecord.where(address_record_id: nil).where.not(street: nil))
    end

    def build_or_create_for(impound_record)
      return impound_record.address_record if impound_record.address_record?

      existing_address_record = AddressRecord.where(kind: :impounded_from).find_by(user_id: impound_record.user_id)
      if existing_address_record.present? && existing_address_record.internal_address_attrs == AddressRecord.new(AddressRecord.attrs_from_legacy(impound_record)).internal_address_attrs
        impound_record.update(address_record: existing_address_record)
        return existing_address_record
      end

      impound_record.address_record = AddressRecord.new(kind: :impounded_from)
      impound_record.address_record.attributes = AddressRecord.attrs_from_legacy(impound_record)
      impound_record.save
      impound_record.address_record
    end
  end

  def build_enumerator(cursor:)
    return if skip_job?

    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(impound_record)
    self.class.build_or_create_for(impound_record)
  end
end
