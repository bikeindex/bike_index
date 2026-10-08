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

    def law = state && StateLaws.find(state[:abbr])
  end
end
