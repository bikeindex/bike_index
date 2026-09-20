# frozen_string_literal: true

module BikeServices
  module OrganizedSearch
    extend Functionable

    STICKER_VALUES = %w[with none].freeze
    # with and none are still accepted, but the panel offers street instead - it reflects
    # people's expectations better
    ADDRESS_VALUES = %w[with_street without_street with none].freeze
    STATUS_VALUES = %w[with_owner stolen all].freeze
    IMPOUND_STATUS_VALUES = %w[not_impounded impounded].freeze

    # Every filter's permitted values, keyed by the param it arrives in - the settings panel
    # offers these, and the controller narrows anything else away
    def filter_values(organization)
      statuses = organization.enabled?("impound_bikes") ? STATUS_VALUES + IMPOUND_STATUS_VALUES : STATUS_VALUES
      {search_stickers: STICKER_VALUES, search_address: ADDRESS_VALUES, search_status: statuses}
    end

    # An impound-enabled organization's registrations leave impounded bikes out unless asked
    def default_status(organization)
      organization.enabled?("impound_bikes") ? "not_impounded" : "all"
    end

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

    def stickers(bikes, value)
      case value
      when "none" then bikes.no_bike_sticker
      when "with" then bikes.bike_sticker
      else bikes
      end
    end

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
