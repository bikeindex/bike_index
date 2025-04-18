# frozen_string_literal: true

class Callbacks::AddressRecordUpdateAssociationsJob < ApplicationJob
  sidekiq_options queue: "med_priority"

  def perform(address_record_id)
    address_record = AddressRecord.find(address_record_id)

    if address_record.user?
      user = address_record.user
      user.latitude = address_record.latitude
      user.longitude = address_record.longitude
      user.save if user.changed?
    end
  end
end
