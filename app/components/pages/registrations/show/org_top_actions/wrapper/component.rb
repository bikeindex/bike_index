# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module OrgTopActions
        module Wrapper
          # The org-admin top action buttons and their accordion panels, wrapped in
          # the `registrations--show--action-panels` Stimulus controller
          class Component < ApplicationComponent
            # Parking-notification statuses that are still ongoing (vs replaced/retrieved/resolved)
            ACTIVE_PARKING_STATUSES = %w[current impounded].freeze

            # [tile background, icon color] per action-icon tile
            TILES = {
              purple: ["tw:bg-purple-100", "tw:text-purple-500"],
              blue: ["tw:bg-[#e7f3fb]", "tw:text-blue-600"],
              amber: ["tw:bg-[#fff8e1]", "tw:text-[#caa11a]"]
            }.freeze

            def initialize(bike:, organization:, org_role:, current_user: nil, display_dev_info: false)
              @bike = bike
              @display_dev_info = display_dev_info
              @organization = organization
              @org_role = org_role
              @current_user = current_user
            end

            private

            def staff?
              @org_role == :staff
            end

            # Centered only below sm, where the button's flex wraps so the icon and subtitle
            # sit on one centered line with the full-width title beneath. From sm it's the
            # flush-left grid: the icon beside a title/subtitle column, which the `1fr`
            # stretches to the button's width
            def action_button(panel_name, icon:, title:, tile: :purple, subtitle: nil)
              classes = "tw:min-h-15 tw:flex-wrap tw:content-center tw:gap-x-3 tw:gap-y-2 tw:rounded-xl tw:p-4! tw:text-center tw:sm:grid! tw:sm:grid-cols-[auto_1fr] tw:sm:gap-y-0.5 tw:sm:text-left tw:lg:flex-1"
              render(UI::Button::Component.new(color: :secondary, size: :lg, html_class: classes, aria: {expanded: false},
                data: {"registrations--show--action-panels-target": "trigger", "panel-name": panel_name,
                       action: "registrations--show--action-panels#toggle"})) do
                safe_join([
                  # Spanning an absent subtitle's row would stretch it to fit the icon,
                  # dropping the title above the icon's center
                  action_icon(icon, tile:, html_class: ("tw:sm:row-span-2" if subtitle.present?)),
                  # Ordered last and full-width so it wraps below the icon/subtitle line
                  content_tag(:span, title, class: "tw:order-1 tw:w-full tw:min-w-0 tw:font-bold tw:sm:col-start-2 tw:sm:row-start-1"),
                  # Left-aligned below sm too, so its stacked lines line up with each other
                  # inside the centered block
                  (content_tag(:span, subtitle, class: "tw:text-left tw:text-xs tw:opacity-60 tw:sm:col-start-2 tw:sm:row-start-2") if subtitle.present?)
                ].compact)
              end
            end

            # The counts don't fit on one line beside the icon below sm, so the active
            # count blocks there — dropping the resolved count onto its own line and
            # hiding the separator that only reads as one on a single line
            def notifications_activity
              safe_join([
                content_tag(:span, translation(".view_notifications_active_html", count: active_notifications_count), class: "tw:block tw:sm:inline"),
                content_tag(:span, " - ", class: "tw:hidden tw:sm:inline"),
                translation(".view_notifications_resolved_html", count: resolved_notifications_count)
              ])
            end

            def action_icon(icon, tile:, html_class: nil)
              tile_classes = TILES.fetch(tile, TILES[:purple])
              content_tag(:span, class: "tw:col-start-1 tw:row-start-1 tw:flex tw:size-9 tw:items-center tw:justify-center tw:rounded-lg #{tile_classes.first} #{html_class}") do
                helpers.inline_svg_tag("kelsey/registration_show/#{icon}.svg", class: "tw:size-[19px] #{tile_classes.last}")
              end
            end

            def impounded?
              @bike.status_impounded?
            end

            # The owner can be messaged (via a stolen/unstolen notification) when the
            # bike is stolen, or when the org can send unstolen notifications
            def contactable?
              @bike.current_stolen_record.present? ||
                (@bike.status_with_owner? && @organization.enabled?("unstolen_notifications"))
            end

            def show_impound?
              @organization.enabled?("impound_bikes")
            end

            # Staff create an impound before it's impounded, and update it after
            def show_create_impound?
              show_impound? && staff? && !impounded?
            end

            def show_update_impound?
              show_impound? && staff? && impounded_by_organization?
            end

            # The update form posts to this org's impound routes, which another
            # org's record - or an unorganized one, which has no display_id - isn't in
            def impounded_by_organization?
              impounded? && @bike.current_impound_record&.organization_id == @organization.id
            end

            def show_parking_notifications?
              @organization.enabled?("parking_notifications")
            end

            # No point filing a new parking notification against an already-impounded bike
            def show_create_parking_notification?
              show_parking_notifications? && !impounded?
            end

            def parking_notifications
              @parking_notifications ||= @organization.parking_notifications.where(bike_id: @bike.id)
            end

            def active_notifications_count
              @active_notifications_count ||= parking_notifications.where(status: ACTIVE_PARKING_STATUSES).count
            end

            def resolved_notifications_count
              @resolved_notifications_count ||= parking_notifications.where.not(status: ACTIVE_PARKING_STATUSES).count
            end
          end
        end
      end
    end
  end
end
