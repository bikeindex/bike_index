# frozen_string_literal: true

module EbikeRuleServices
  # A check of one bike against one state: the state from its page's path, the bike from the query.
  # Only the bike's fields make it a check, so a state's page alone, or with the manual panel just opened, shows no errors.
  # A manual check needs no wattage, which the evaluator reports as not provided
  Lookup = Data.define(:state, :detected_state, :bikebook_id, :manual, :manual_mph, :manual_watts,
    :manual_throttle, :bike, :errors, :submitted) do
    def self.from_params(params, state: nil, detected_state: nil)
      manual = params[:manual] == "1"
      submitted = params.key?(:vehicle_models) || (manual && params.key?(:top_speed))
      manual_mph = params[:top_speed].to_i.clamp(20, 29)
      manual_watts = params[:watts].to_i.then { it if it.positive? }
      manual_throttle = params[:throttle] == "1"
      bike = if manual
        Bike.manual(top_mph: manual_mph, watts: manual_watts, throttle: manual_throttle)
      elsif submitted
        BikebookVehicles.find(params[:vehicle_models])
      end
      errors = if submitted
        [(:state if state.nil?), (:bike if bike.nil?)].compact
      else
        []
      end

      new(state:, detected_state:, bikebook_id: params[:vehicle_models].presence, manual:, manual_mph:, manual_watts:,
        manual_throttle:, bike:, errors:, submitted:)
    end

    def result? = submitted && errors.none?

    # A model whose details were changed, which checks the details
    def custom? = manual && bikebook_id.present?

    # The details panel's values: the entered ones, or the model's own, which the browser copies in after a pick
    def details
      return {} unless submitted && bike

      throttle = {true => 1, false => 0}
      if manual
        {top_speed: manual_mph, throttle: throttle[manual_throttle], watts: manual_watts}
      else
        {top_speed: model_top_speed, throttle: throttle[bike.throttle], watts: bike.watts || bike.peak_watts}
      end
    end

    # Its fastest mode's, or without a speed on record, the answer a hand entry would take to reach its class - over
    # 28 mph for one classified as something else. Blank for a model whose class the catalog can't tell
    def model_top_speed
      mph = [bike.top_assist_mph, bike.throttle_mph].compact.max
      return [20, 28].find { mph <= it } || 29 if mph
      return if bike.class_unknown

      {1 => 20, 2 => 20, 3 => 28}.fetch(bike.e_bike_class, 29)
    end

    def law = state && StateLaws.find(state[:abbr])
  end
end
