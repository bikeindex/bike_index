# frozen_string_literal: true

module EbikeRuleServices
  # A bike checked against a state's e-bike rules: a Bike Book model, or one entered by hand,
  # which has no bikebook_id. e_bike_class is nil for a motorized vehicle that isn't Class 1, 2 or 3,
  # and e_vehicle_classifications are the ids its catalog record carries.
  # ul2849 and ul2271 are :certified or :unknown
  Bike = Data.define(:bikebook_id, :manufacturer_name, :model, :first_year, :e_bike_class, :e_vehicle_classifications,
    :watts, :top_assist_mph, :throttle, :throttle_mph, :ul2849, :ul2271, :photo_url) do
    def self.manual(e_bike_class:, watts:, throttle:)
      new(bikebook_id: nil, manufacturer_name: nil, model: nil, first_year: nil, e_bike_class:, e_vehicle_classifications: [],
        watts:, top_assist_mph: nil, throttle:, throttle_mph: nil, ul2849: :unknown, ul2271: :unknown, photo_url: nil)
    end

    def manual? = bikebook_id.nil?

    def make_and_model = [manufacturer_name, model].compact.join(" ")
  end
end
