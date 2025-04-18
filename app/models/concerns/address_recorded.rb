# frozen_string_literal: true

module AddressRecorded
  extend ActiveSupport::Concern

  included do
    belongs_to :address_record
    accepts_nested_attributes_for :address_record

    delegate :address_hash, to: :address_record, allow_nil: true
  end

  def to_coordinates
    [latitude, longitude]
  end
end
