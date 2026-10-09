# frozen_string_literal: true

module EbikeRuleServices
  # A bike checked against a state's e-bike rules: a Bike Book model, or one entered by hand,
  # which has no bikebook_id. e_bike_class is nil for a motorized vehicle that isn't Class 1, 2 or 3, or
  # whose record says too little to tell, which is class_unknown. e_vehicle_classifications are the ids its record carries.
  # ul2849 and ul2271 are :certified or :unknown, or :unrecorded for a bike entered by hand
  Bike = Data.define(:bikebook_id, :manufacturer_name, :model, :first_year, :e_bike_class, :class_unknown,
    :e_vehicle_classifications, :watts, :top_assist_mph, :throttle, :throttle_mph, :ul2849, :ul2271, :photo_url) do
    # Classed by the federal limits, as BikebookVehicles classes an unclassified model; over 28 mph is none
    def self.manual(top_mph:, watts:, throttle:)
      e_bike_class = case top_mph
      when ..20 then throttle ? 2 : 1
      when ..28 then 3
      end
      new(bikebook_id: nil, manufacturer_name: nil, model: nil, first_year: nil, e_bike_class:, class_unknown: false,
        e_vehicle_classifications: [],
        watts:, top_assist_mph: (top_mph if e_bike_class), throttle:, throttle_mph: nil, ul2849: :unrecorded, ul2271: :unrecorded, photo_url: nil)
    end

    def manual? = bikebook_id.nil?

    # Every class its record carries, as assist to 28 mph with a throttle to 20 is both Class 2 and 3. [nil] for a
    # bike with no class, whose record can still carry a US one beside a moped's
    def e_bike_classes
      return [nil] if e_bike_class.nil?

      e_vehicle_classifications.filter_map { it[EbikeRuleServices::BikebookCatalog::US_CLASS, 1]&.to_i }.sort.presence || [e_bike_class]
    end

    # Entered by hand as faster than any class, so its top speed is only known to be past Class 3's
    def assists_past_mph = (28 if manual? && e_bike_class.nil?)

    def make_and_model = [manufacturer_name, model].compact.join(" ")
  end
end
