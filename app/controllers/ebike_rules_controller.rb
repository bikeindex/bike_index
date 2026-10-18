# frozen_string_literal: true

class EbikeRulesController < ApplicationController
  LOOKUP_PARAMS = %i[vehicle_models manual top_speed watts throttle].freeze

  def show
    # a form's place - the lookup's without JavaScript, or the country switch's - which can't send it to the place's own page
    query = request.query_parameters
    if (key = %w[state country].find { query.key?(it) })
      code, query = query[key], query.except(key)
      chosen = place_for(code)
      path = if chosen
        place_path(chosen, query)
      elsif code == "US"
        ebike_rules_place_path("US", query)
      else
        ebike_rules_path(query)
      end
      return redirect_to(path, status: :moved_permanently)
    end

    code = params[:country] && [params[:country], params[:region]].compact.join("-")
    # /ebike-rules/US, the US chosen from outside it, which picks no state
    us_chosen = code == "US"
    place = place_for(code) || raise(ActionController::RoutingError, "Not Found") if code && !us_chosen
    return redirect_to(place_path(place, request.query_parameters), status: :moved_permanently) if place && place[:code] != code
    if turbo_frame_request_id == Pages::EbikeRules::Classes::Component::FRAME_ID
      return render(Pages::EbikeRules::Classes::Component.new(place:))
    end
    if turbo_frame_request_id&.start_with?(Pages::EbikeRules::ClassCard::Component::FRAME_ID)
      e_bike_class = params[:e_bike_class].to_i.then { it if (1..3).cover?(it) }
      classification = params[:classification].presence&.then { EbikeRuleServices::StateLaws.classification(it) || raise(ActionController::RoutingError, "Not Found") }
      return render(Pages::EbikeRules::ClassCard::Component.new(e_bike_class:, classification:, place:, frame_id: turbo_frame_request_id))
    end

    detected_place = EbikeRuleServices::Places.from_location(request_location_hash)
    # where they chose it, rather than sending them back
    detected_place = nil if us_chosen && detected_place && !EbikeRuleServices::Places.us?(detected_place)
    if place.nil?
      # which place it goes to depends on where the visitor is, so neither Cloudflare nor a browser keeps it. A bike
      # comes along, as from Bike Book's link; a frame's check waits for the place the form hasn't chosen
      response.headers["Cache-Control"] = "no-store"
      return redirect_to place_path(detected_place, request.query_parameters) if detected_place && !turbo_frame_request?
    end

    assign_meta(place)
    @page_url = ebike_rules_url if us_chosen
    lookup = EbikeRuleServices::Lookup.from_params(params.permit(*LOOKUP_PARAMS), place:, detected_place:)
    return render(Pages::EbikeRules::Check::Component.new(lookup:, page_title: @page_title)) if turbo_frame_request?

    registered_count, recoveries_count = Counts.retrieve_many("total_bikes", "recoveries")
    render Pages::EbikeRules::Show::Component.new(lookup:, manifest_url: Integrations::Bikebook::Catalog::MANIFEST_URL,
      registered_count:, recoveries_count:, page_title: @page_title, default_title: country_title(lookup.country))
  end

  private

  # US-CA's is /ebike-rules/US/CA
  def place_path(place, query = {}) = ebike_rules_place_path(*place[:code].split("-"), query)

  # Two lowercase letters were a US state's before places outside the US had pages, as two uppercase ones still are
  # where no place has them. The rest are a place's code in any case
  def place_for(code)
    return unless code.is_a?(String)

    us = (state = EbikeRuleServices::StateLaws.state(code)) && EbikeRuleServices::Places.find("US-#{state[:abbr]}")
    (code == code.downcase && us) || EbikeRuleServices::Places.find(code.upcase) || us
  end

  def default_title = translation(:title, controller_method: :show)

  # The page a place cleared from the form goes to: /ebike-rules, or a checked country's own
  def country_title(country)
    return default_title if country == "US"

    translation(:state_title, state: EbikeRuleServices::Places.find(country)&.dig(:name) || country, controller_method: :show)
  end

  # The place's own, however the page was reached - a check's bike params don't change them
  def assign_meta(place)
    return @page_title = default_title if place.nil?

    name = place[:name]
    law = if EbikeRuleServices::Places.us?(place)
      EbikeRuleServices::StateLaws.find(place[:abbr])
    else
      EbikeRuleServices::StateLaws.places.dig(place[:code], :laws)&.first
    end
    @page_url = ebike_rules_place_url(*place[:code].split("-"))
    @page_title = translation(:state_title, state: name, controller_method: :show)
    @page_description = if law
      translation(:state_description, state: name, law: law[:description], controller_method: :show)
    else
      translation(:state_description_in_review, state: name, controller_method: :show)
    end.truncate(200, separator: " ")
  end
end
