# frozen_string_literal: true

module EbikeRuleServices
  # A bike checked against a state's e-bike rules: a Bike Book model, or one entered by hand,
  # which has no bikebook_id. e_bike_class is nil for a motorized vehicle that isn't Class 1, 2 or 3, or
  # whose record says too little to tell, which is class_unknown. e_vehicle_classifications are the ids its record carries.
  # vehicle_type is its catalog type, "cargo_bike". stock_throttle is a throttle it's sold with, rather than one sold separately. optional_classes are the US classes only
  # a mode it isn't sold with - an upgrade, an app update - brings, by that mode's name, "throttle" or "assist".
  # ul2849 and ul2271 are :certified or :unknown, or :unrecorded for a bike entered by hand. watts is rated power, which
  # states cap; peak_watts only stands in for a model the catalog records no rating for. Speeds are in km/h too, as the
  # catalog records them, for a law outside the US; assists_past_kmh is a hand entry's, past any speed it gives
  Bike = Data.define(:bikebook_id, :manufacturer_name, :model, :first_year, :vehicle_type, :e_bike_class, :class_unknown,
    :e_vehicle_classifications, :optional_classes, :watts, :peak_watts, :top_assist_mph, :top_assist_kmh, :assists_past_kmh,
    :throttle, :stock_throttle, :throttle_mph, :throttle_kmh, :ul2849, :ul2271, :photo_url) do
    # Classed by the federal limits, as BikebookVehicles classes an unclassified model; over 28 mph is none. A Class 3
    # with a throttle is Class 2 as well, as a model whose assist reaches 28 mph and whose throttle stops at 20 is
    def self.manual(top_mph:, watts:, throttle:)
      e_bike_class = case top_mph
      when ..20 then throttle ? 2 : 1
      when ..28 then 3
      end
      classes = (e_bike_class == 3 && throttle) ? [2, 3] : [e_bike_class].compact
      new(bikebook_id: nil, manufacturer_name: nil, model: nil, first_year: nil, vehicle_type: "bike", e_bike_class:, class_unknown: false,
        e_vehicle_classifications: classes.map { "evc/us/class_#{it}" }, optional_classes: {}, watts:, peak_watts: nil,
        top_assist_mph: (top_mph if e_bike_class), top_assist_kmh: (UnitSystem.miles_to_kilometers(top_mph).round if e_bike_class),
        assists_past_kmh: (45 unless e_bike_class), throttle:, stock_throttle: throttle, throttle_mph: nil, throttle_kmh: nil,
        ul2849: :unrecorded, ul2271: :unrecorded, photo_url: nil)
    end

    # Entered as within a Canadian law's 32 km/h, or past it, which is past Class 1 and 2's 20 mph too
    def self.manual_metric(top_kmh:, watts:, throttle:)
      within = top_kmh <= 32
      manual(top_mph: within ? 20 : 29, watts:, throttle:).with(top_assist_kmh: (top_kmh if within), assists_past_kmh: (32 unless within))
    end

    def manual? = bikebook_id.nil?

    # Every class its record carries, as assist to 28 mph with a throttle to 20 is both Class 2 and 3. [nil] for a
    # bike with no class, whose record can still carry a US one beside a moped's
    def e_bike_classes
      return [nil] if e_bike_class.nil?

      e_vehicle_classifications.filter_map { it[EbikeRuleServices::BikebookCatalog::US_CLASS, 1]&.to_i }.sort.presence || [e_bike_class]
    end

    # The classes it's sold as
    def stock_e_bike_classes = e_bike_classes - optional_classes.keys

    def optional_throttle? = throttle && !stock_throttle

    # Under a law whose Class 3 can't have a throttle, as California's (Vehicle Code §312.5), one with a stock throttle
    # is in no class, and one with an optional throttle is in none with it
    def out_of_class_under?(law) = class_3_throttle_banned?(law) && stock_throttle

    def optionally_out_of_class_under?(law) = class_3_throttle_banned?(law) && optional_throttle?

    def class_3_throttle_banned?(law) = law&.dig(:class_3_throttle) == false && e_bike_classes.include?(3)

    # Entered by hand as faster than any class, so its top speed is only known to be past Class 3's
    def assists_past_mph = (28 if manual? && e_bike_class.nil?)

    # A law outside the US caps the motor's speed however it's reached
    def top_kmh = [top_assist_kmh, throttle_kmh].compact.max

    def make_and_model = [manufacturer_name, model].compact.join(" ")
  end
end
