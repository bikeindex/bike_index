# Geocoding and address handling for ParkingNotification.
# Includes Geocodeable and adds ParkingNotification-specific behavior:
# - geocoded_by :formatted_address_string (for bounding box search)
# - skip_geocoding support
# - latitude_public/longitude_public
module GeocodeableParkingNotification
  extend ActiveSupport::Concern
  include Geocodeable

  included do
    geocoded_by :formatted_address_string

    attr_accessor :skip_geocoding

    scope :with_location, -> { where.not(latitude: nil) }
    scope :with_street, -> { with_location.where.not(street: nil) }
    scope :without_street, -> { where(street: ["", nil]) }
  end
end
