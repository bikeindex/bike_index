# frozen_string_literal: true

module Admin
  module Bikes
    module Tabs
      # The bike summary and tab bar above every admin page scoped to one bike.
      # active_tab is the tab's identifier ("bikes-edit", "theft_alerts"...); pages
      # that aren't reachable from a tab pass nothing.
      class Component < ApplicationComponent
        def initialize(bike:, active_tab: nil, stolen_record: nil, display_recovery: nil)
          @bike = bike
          @active_tab = active_tab
          @stolen_record = stolen_record.presence || @bike&.fetch_current_stolen_record
          @display_recovery = display_recovery || @stolen_record&.recovered? || false
        end

        private

        def nav_link_class(tab)
          "nav-link#{" active" if @active_tab == tab}"
        end

        # Cache the counts, not the rendered tabs, so the key doesn't depend on the active tab
        def tab_counts
          @tab_counts ||= Rails.cache.fetch(["admin_bike_tab_counts-1", @bike]) do
            {duplicates: @bike.duplicate_bike_groups.count,
             messages: @bike.messages_count,
             marketplace_listings: @bike.marketplace_listings.count,
             ownerships: @bike.ownerships.count,
             bike_stickers: @bike.bike_stickers.count,
             theft_alerts: @bike.theft_alerts.count,
             recoveries: @bike.recovered_records.count,
             impound: @bike.impound_records.count + ImpoundClaim.involving_bike_id(@bike.id).count}
          end
        end

        def unregistered_parking_notification
          @bike.parking_notifications.reorder(:created_at).first
        end

        def bike_search_url
          return admin_bikes_path(user_id: @bike.user.id) if @bike.user.present?

          admin_bikes_path(search_email: @bike.owner_email)
        end

        # Displayed as JSON-ish rather than a ruby hash, to make it a little easier to read
        def address_display(address)
          "{#{address.map { |key, value| "#{key}: #{"\"#{value}\"" if value.present?}" }.join(", ")}}"
        end

        def registration_address
          @registration_address ||= @bike.registration_address
        end

        def address_hash
          @address_hash ||= @bike.address_hash
        end
      end
    end
  end
end
