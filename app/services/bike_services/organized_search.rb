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

    LOCATIONABLE_STATUSES = %w[stolen impounded stolen_or_impounded].freeze

    def location_searchable?(organization:, search_all:, search_status:)
      LOCATIONABLE_STATUSES.include?(search_status) || registration_address_searchable?(organization:, search_all:)
    end

    # Ignored where it isn't searchable, as the disabled field is. Only a stolen bike's own
    # coordinates are safe to search - any other's can be its owner's or its organization's
    def location(bikes, location, distance, organization:, search_all: false, search_status: nil, ip_address: nil)
      return bikes if location.blank? || location.match?(/anywhere/i) ||
        !location_searchable?(organization:, search_all:, search_status:)

      proximity = BikeSearchable.proximity_bounding_box(location, distance, ip_address)
      return bikes.none if proximity.nil?

      bounding_box = proximity[:bounding_box]
      # EXISTS rather than IN: an IN subquery inside an OR can't use an index, so it scans
      # every address record. Skipping the arm the status rules out keeps the lat/lng index
      matches = []
      matches << bikes.status_stolen.within_bounding_box(bounding_box) unless search_status == "impounded"
      unless search_status == "stolen"
        matches << bikes.where(ImpoundRecord.within_bounding_box(bounding_box)
          .where("impound_records.id = bikes.current_impound_record_id").arel.exists)
      end
      if registration_address_searchable?(organization:, search_all:)
        matches << bikes.where(AddressRecord.within_bounding_box(bounding_box)
          .where("address_records.id = bikes.address_record_id").arel.exists)
      end
      matches.reduce(:or)
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
      when "stolen_or_impounded" then bikes.stolen_or_impounded
      else bikes.where(status: "status_#{value}")
      end
    end

    #
    # private below here
    #

    def registration_address_searchable?(organization:, search_all:)
      !search_all && organization.enabled?("reg_address")
    end

    conceal :registration_address_searchable?
  end
end
