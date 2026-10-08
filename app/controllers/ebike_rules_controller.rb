# frozen_string_literal: true

class EbikeRulesController < ApplicationController
  LOOKUP_PARAMS = %i[bike manual e_bike_class watts throttle].freeze

  def show
    # the form's state without JavaScript, which can't send it to the state's own page
    if params.key?(:state)
      chosen = EbikeRuleServices::StateLaws.state(params[:state])
      query = request.query_parameters.except("state")
      return redirect_to(chosen ? state_path(chosen, query) : ebike_rules_path(query), status: :moved_permanently)
    end

    abbr = params[:abbr]
    state = abbr && (EbikeRuleServices::StateLaws.state(abbr) || raise(ActionController::RoutingError, "Not Found"))
    return redirect_to(state_path(state, request.query_parameters), status: :moved_permanently) if abbr && abbr != abbr.downcase

    detected_state = EbikeRuleServices::StateLaws.state_from_location(request_location_hash)
    if state.nil?
      # which state it goes to depends on where the visitor is, so neither Cloudflare nor a browser keeps it
      response.headers["Cache-Control"] = "no-store"
      if detected_state && (LOOKUP_PARAMS.map(&:to_s) & request.query_parameters.keys).none?
        return redirect_to state_path(detected_state, request.query_parameters)
      end
    end

    assign_meta(state)
    lookup = EbikeRuleServices::Lookup.from_params(params.permit(*LOOKUP_PARAMS), state:, detected_state:)
    registered_count, recoveries_count = Counts.retrieve_many("total_bikes", "recoveries")
    render Pages::EbikeRules::Show::Component.new(lookup:, manifest_url: Integrations::Bikebook::Catalog::MANIFEST_URL,
      registered_count:, recoveries_count:)
  end

  private

  def state_path(state, query = {}) = ebike_rules_state_path(state[:abbr].downcase, query)

  # The state's own, however the page was reached - a check's bike params don't change them
  def assign_meta(state)
    return @page_title = translation(:title, controller_method: :show) if state.nil?

    name = state[:name]
    law = EbikeRuleServices::StateLaws.find(state[:abbr])
    @page_url = ebike_rules_state_url(state[:abbr].downcase)
    @page_title = translation(:state_title, state: name, controller_method: :show)
    @page_description = if law
      translation(:state_description, state: name, law: law[:description], controller_method: :show)
    else
      translation(:state_description_in_review, state: name, controller_method: :show)
    end.truncate(200, separator: " ")
  end
end
