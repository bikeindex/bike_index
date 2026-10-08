# frozen_string_literal: true

module EbikeRuleServices
  # A check of one bike against one state: the state from its page's path, the bike from the query.
  # Only the bike's fields make it a check, so a state's page alone shows no errors
  Lookup = Data.define(:state, :detected_state, :bikebook_id, :manual, :manual_class, :manual_watts,
    :manual_throttle, :bike, :errors, :submitted) do
    def self.from_params(params, state: nil, detected_state: nil)
      manual = params[:manual] == "1"
      submitted = manual || params.key?(:bike)
      manual_class = params[:e_bike_class].present? ? params[:e_bike_class].to_i.clamp(1, 3) : 2
      manual_watts = params[:watts].to_i.then { it if it.positive? }
      manual_throttle = params[:throttle] != "0"
      bike = if manual
        Bike.manual(e_bike_class: manual_class, watts: manual_watts, throttle: manual_throttle) if manual_watts
      elsif submitted
        BikebookVehicles.find(params[:bike])
      end
      errors = if submitted
        [(:state if state.nil?), ((manual ? :watts : :bike) if bike.nil?)].compact
      else
        []
      end

      new(state:, detected_state:, bikebook_id: params[:bike].presence, manual:, manual_class:, manual_watts:,
        manual_throttle:, bike:, errors:, submitted:)
    end

    def result? = submitted && errors.none?

    def law = state && StateLaws.find(state[:abbr])
  end
end
