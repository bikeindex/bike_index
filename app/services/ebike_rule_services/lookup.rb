# frozen_string_literal: true

module EbikeRuleServices
  # A check of one bike against one place: the place from its page's path, the bike from the query.
  # Only the bike's fields make it a check, so a place's page alone, or with the manual panel just opened, shows no errors.
  # A manual check needs no wattage, which the evaluator reports as not provided. A US state's law checks a bike, as a
  # Canadian province's does, whose top speed is entered in km/h
  Lookup = Data.define(:place, :detected_place, :bikebook_id, :manual, :manual_top_speed, :manual_watts,
    :manual_throttle, :manual_throttle_speed, :bike, :errors, :submitted) do
    def self.from_params(params, place: nil, detected_place: nil)
      manual = params[:manual] == "1"
      submitted = params.key?(:vehicle_models) || (manual && params.key?(:top_speed))
      us = Places.checked_country(place) == "US"
      cap = Places::CANADA_SPEED_CAP_KMH
      speeds = us ? [20, 29] : [cap, cap + 1]
      manual_top_speed = params[:top_speed].to_i.clamp(*speeds)
      manual_watts = params[:watts].to_i.then { it if it.positive? }
      manual_throttle = params[:throttle] == "1"
      manual_throttle_speed = (params[:throttle_speed].to_i.clamp(*(us ? [20, 21] : speeds)) if manual_throttle && params[:throttle_speed].present?)
      bike = if manual && us
        Bike.manual(top_mph: manual_top_speed, watts: manual_watts, throttle: manual_throttle, throttle_mph: manual_throttle_speed)
      elsif manual
        Bike.manual_metric(top_kmh: manual_top_speed, watts: manual_watts, throttle: manual_throttle, throttle_kmh: manual_throttle_speed)
      elsif submitted
        BikebookVehicles.find(params[:vehicle_models])
      end
      # a checked country's own page has no region's law to check against
      errors = if submitted
        [(:state if place.nil? || Places::CHECKED_COUNTRIES.include?(place[:code])), (:bike if bike.nil?)].compact
      else
        []
      end

      new(place:, detected_place:, bikebook_id: params[:vehicle_models].presence, manual:, manual_top_speed:, manual_watts:,
        manual_throttle:, manual_throttle_speed:, bike:, errors:, submitted:)
    end

    def result? = submitted && errors.none? && Places.checks?(place)

    def country = Places.checked_country(place)

    def us? = country == "US"

    # The details panel's values: the entered ones, or the model's own, which the browser copies in after a pick
    def details
      return {} unless submitted && bike

      top_speed, throttle, throttle_speed, watts = if manual
        [manual_top_speed, manual_throttle, manual_throttle_speed, manual_watts]
      else
        [model_top_speed, bike.throttle, model_throttle_speed, bike.motor_watts]
      end
      {top_speed:, throttle: {true => 1, false => 0}[throttle], throttle_speed:, watts:}
    end

    def law
      return if place.nil?

      Places.us?(place) ? StateLaws.find(place[:abbr]) : StateLaws.place_law(place[:code])
    end

    private

    # Without a speed on record, the answer a hand entry would take to reach its class - over
    # 28 mph for one classified as something else. Blank for a model whose class the catalog can't tell
    def model_top_speed
      return model_top_kmh unless us?

      mph = bike.top_assist_mph || bike.throttle_mph
      return speed_answer(mph, [20, 28, 29]) if mph
      return if bike.class_unknown

      {1 => 20, 2 => 20, 3 => 28}.fetch(bike.e_bike_class, 29)
    end

    def model_top_kmh
      kmh = bike.top_assist_kmh || bike.throttle_kmh
      return speed_answer(kmh, canada_speeds) if kmh
      return if bike.class_unknown

      cap = Places::CANADA_SPEED_CAP_KMH
      [1, 2].include?(bike.e_bike_class) ? cap : cap + 1
    end

    def model_throttle_speed
      return bike.throttle_mph && speed_answer(bike.throttle_mph, [20, 21]) if us?

      bike.throttle_kmh && speed_answer(bike.throttle_kmh, canada_speeds)
    end

    def speed_answer(speed, answers) = answers.find { speed <= it } || answers.last

    def canada_speeds = [Places::CANADA_SPEED_CAP_KMH, Places::CANADA_SPEED_CAP_KMH + 1]
  end
end
