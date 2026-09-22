# frozen_string_literal: true

module BikeServices
  module OrganizedSearch
    extend Functionable

    # Reaching past the organization matches most of the index, so the count - and the
    # pagination, and what the results card says it found - stop here
    SEARCH_ALL_COUNT_LIMIT = 1_000

    def email_and_name(bikes, query)
      return bikes unless query.present?

      query_string = "%#{query.strip}%"
      bikes.includes(:current_ownership)
        .where("bikes.owner_email ilike ? OR ownerships.owner_name ilike ?", query_string, query_string)
        .references(:current_ownership)
    end

    def notes(bikes, query, organization)
      return bikes unless query.present?

      query_string = "%#{query.strip}%"
      bikes.joins(:bike_organization_notes)
        .where(bike_organization_notes: {organization_id: organization.id})
        .where("bike_organization_notes.body ILIKE ?", query_string)
    end

    # A stolen or impounded bike is where it was taken or impounded; any other is at its
    # registration address - only matched where the organization collects that, and only
    # among its own registrations
    def location(bikes, location, distance, organization:, search_all: false, ip_address: nil)
      return bikes if location.blank?

      proximity = BikeSearchable.proximity_bounding_box(location, distance, ip_address)
      return bikes if proximity.nil? && location.match?(/anywhere/i)
      return bikes.none if proximity.nil?

      bikes = bikes.stolen_or_impounded if search_all || !organization.enabled?("reg_address")
      bikes.within_bounding_box(proximity[:bounding_box])
    end

    def stickers(bikes, value)
      case value
      when "none" then bikes.no_bike_sticker
      when "with" then bikes.bike_sticker
      else bikes
      end
    end

    # none and with are removed in favour of street - it reflects people's expectations better
    def address(bikes, value)
      case value
      when "none" then bikes.without_location
      when "without_street" then bikes.without_street
      when "with_street" then bikes.with_street
      when "with" then bikes.with_location
      else bikes
      end
    end

    def status(bikes, value)
      case value
      when "all" then bikes
      when "not_impounded" then bikes.where.not(status: "status_impounded")
      else bikes.where(status: "status_#{value}")
      end
    end
  end
end
