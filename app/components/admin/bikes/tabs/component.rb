# frozen_string_literal: true

module Admin
  module Bikes
    module Tabs
      class Component < ApplicationComponent
        TABS = %i[edit duplicates messages listings ownerships stickers stolen theft_alerts
          recoveries impound recovery_displays].freeze

        # active: is passed rather than read off the route because half of these tabs are
        # another controller's index screen, filtered to this bike
        def initialize(bike:, active:, stolen_record: nil, display_recovery: false)
          raise_if_invalid_value!(:active, active, TABS)

          @bike = bike
          @active = active
          @stolen_record = stolen_record || bike.fetch_current_stolen_record
          @display_recovery = display_recovery || @stolen_record&.recovered?
        end

        private

        def title
          safe_join([helpers.bike_status_span(@bike), @bike.title_string].reject(&:blank?), " ")
        end

        def tabs
          [[:edit, "Edit", edit_admin_bike_path(@bike)],
            [:duplicates, "Duplicates", admin_bike_path(@bike, active_tab: "duplicates"), tab_counts[:duplicates]],
            [:messages, "Messages", admin_bike_path(@bike, active_tab: "messages"), tab_counts[:messages]],
            [:listings, "Listings", admin_marketplace_listings_path(search_bike_id: @bike.id), tab_counts[:listings]],
            [:ownerships, "Ownerships", admin_bike_path(@bike, active_tab: "ownerships"), tab_counts[:ownerships]],
            [:stickers, "Stickers", admin_bike_path(@bike, active_tab: "stickers"), tab_counts[:stickers]],
            (stolen_tab if @stolen_record.present?),
            [:theft_alerts, "Promoted alerts", admin_theft_alerts_path(search_bike_id: @bike.id), tab_counts[:theft_alerts]],
            [:recoveries, "Recoveries", admin_bike_path(@bike, active_tab: "recoveries"), tab_counts[:recoveries]],
            ([:impound, "Impoundings", admin_bike_path(@bike, active_tab: "impound"), tab_counts[:impound]] if impound?),
            ([:recovery_displays, "Recovery displays", admin_recovery_displays_path(search_bike_id: @bike.id)] if @display_recovery)]
            .compact.map { |tab, label, href, count|
              ComponentStructs::Shapes.tab(label, href, count:, active: @active == tab)
            }
        end

        # Cache the counts rather than the markup: which tab is active varies per screen and
        # comes from an unvalidated param, so it can't go in a cache key
        def tab_counts
          @tab_counts ||= Rails.cache.fetch(["admin_bike_tab_counts-1", @bike]) do
            {duplicates: @bike.duplicate_bike_groups.count, messages: @bike.messages_count,
             listings: @bike.marketplace_listings.count, ownerships: @bike.ownerships.count,
             stickers: @bike.bike_stickers.count, theft_alerts: @bike.theft_alerts.count,
             recoveries: @bike.recovered_records.count,
             impound: @bike.impound_records.count + ImpoundClaim.involving_bike_id(@bike.id).count}
          end
        end

        def stolen_tab
          [:stolen, "Stolen #{@stolen_record.approved? ? "✅" : "❌"}",
            edit_admin_stolen_bike_url(@stolen_record.id, stolen_record_id: true)]
        end

        # A tab with nothing behind it is dropped - except on its own page, which still
        # renders and shouldn't lose its place in the row
        def impound? = tab_counts[:impound] > 0 || @active == :impound

        def non_admin_view_link
          render(UI::ButtonLink::Component.new(text: "non-admin view", size: :sm,
            href: bike_path(@bike.to_param, organization_id: @bike.creation_organization&.to_param)))
        end

        # Bike.current is the scope that drops all four of the states the alerts explain
        def alerts? = !@bike.current?

        def unregistered_parking_notification
          @unregistered_parking_notification ||= @bike.parking_notifications.reorder(:created_at).first
        end
      end
    end
  end
end
