# frozen_string_literal: true

class Backfills::AddressRecordsForUsersJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority"

  class << self
    def iterable_scope
      User.where.not(latitude: nil).where(address_record_id: nil)
    end

    def build_or_create_for(user, country_id: nil)
      return user.address_record if user.address_record.present?

      user.address_record = AddressRecord.new(user_id: user.id, kind: :user, country_id:)

      return user.address_record if user.latitude.blank? || user.longitude.blank?

      user.address_record.attributes = AddressRecord.attrs_from_legacy(user)
      user.skip_update = true
      user.save
      user.address_record.skip_geocoding = false
      user.address_record
    end
  end

  def build_enumerator(cursor:)
    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(address_record)
    self.class.build_or_create_for(address_record)
  end
end
