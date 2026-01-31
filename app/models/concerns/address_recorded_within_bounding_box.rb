# frozen_string_literal: true

# Ownership does not have coordinates, but does include AddressRecorded
# So this needs to be a separate concern
module AddressRecordedWithinBoundingBox
  extend ActiveSupport::Concern

  included do
    # This duplicates the functionality of Geocoder::Store::ActiveRecord.within_bounding_box
    scope :within_bounding_box, lambda { |*bounds|
      sw_lat, sw_lng, ne_lat, ne_lng = bounds.flatten if bounds
      return none unless sw_lat && sw_lng && ne_lat && ne_lng

      joins(:address_record).where(address_records: {latitude: sw_lat..ne_lat, longitude: sw_lng..ne_lng})
    }

    scope :with_location, -> { joins(:address_record).where.not(address_records: {latitude: nil}) }
    scope :without_location, -> { left_joins(:address_record).where(address_records: {latitude: nil}) }
  end

  def to_coordinates
    [address_record&.latitude, address_record&.longitude]
  end
end
