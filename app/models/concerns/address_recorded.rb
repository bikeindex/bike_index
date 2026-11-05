# frozen_string_literal: true

module AddressRecorded
  extend ActiveSupport::Concern

  included do
    belongs_to :address_record, autosave: true
    accepts_nested_attributes_for :address_record

    delegate :address_present?, :address_hash, :formatted_address_string,
      to: :address_record, allow_nil: true

    scope :address_record, -> { where.not(address_record_id: nil) }
    scope :with_street, -> { includes(:address_record).where.not(address_records: {street: nil}) }
    scope :without_street, -> { includes(:address_record).where(address_records: {street: nil}) }
  end

  def address_record?
    address_record.present?
  end
end
