# frozen_string_literal: true

class EbikeRulesController < ApplicationController
  def show
    @page_title = "E-bike rules"
    lookup = EbikeRules::Lookup.from_params(params.permit(:state, :bike, :manual, :e_bike_class, :watts, :throttle),
      detected_state: EbikeRules::StateLaws.state_from_location(request_location_hash))
    render Pages::EbikeRules::Show::Component.new(lookup:, manifest_url: BikebookController::MANIFEST_URL,
      registered_count: Counts.total_bikes, recoveries_count: Counts.recoveries)
  end
end
