# frozen_string_literal: true

class CallbackJob::AddressRecordUpdateAssociationsJob < ApplicationJob
  sidekiq_options queue: "med_priority"

  def perform(address_record_id)
    address_record = AddressRecord.find_by(id: address_record_id)
    return if address_record.blank?

    if address_record.user? && address_record.user.present?
      address_record.user.address_record_id ||= address_record.id

      if address_record.user.address_record_id == address_record.id
        update_association(address_record, address_record.user)
      end
    elsif address_record.kind.blank?
      # Currently just handles marketplace_listings, but can be easily updated!
      if address_record.marketplace_listings.any?
        address_record.kind = :marketplace_listing
        address_record.user_id ||= address_record.marketplace_listings.first.seller_id
        address_record.update(skip_callback_job: true)
      end
    end

    address_record.marketplace_listings.each { update_association(address_record, it) }
  end

  private

  def update_association(address_record, association)
    association.latitude = address_record.latitude
    association.longitude = address_record.longitude
    association.save if association.changed?
  end
end
