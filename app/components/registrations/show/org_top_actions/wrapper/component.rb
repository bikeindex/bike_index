# frozen_string_literal: true

module Registrations
  module Show
    module OrgTopActions
      module Wrapper
        # The org-admin top action buttons and their accordion panels, wrapped in
        # the `registrations--show--action-panels` Stimulus controller
        class Component < ApplicationComponent
          # Parking-notification statuses that are still ongoing (vs replaced/retrieved/resolved)
          ACTIVE_PARKING_STATUSES = %w[current impounded].freeze

          def initialize(bike:, organization:, staff:)
            @bike = bike
            @organization = organization
            @staff = staff
          end

          private

          # A grid rather than the button's default flex, so below sm the icon, title
          # and subtitle each take a full-width row, while from sm the icon spans the
          # title and subtitle rows beside them. The title's margin only applies to
          # the stacked layout, separating it from the icon above rather than the
          # subtitle below.
          def action_button(panel_name, icon:, title:, tile: :purple, subtitle: nil)
            classes = "tw:relative tw:grid! tw:w-full tw:min-h-[60px] tw:grid-cols-1 tw:content-center tw:gap-y-0.5 tw:rounded-xl tw:p-4! tw:text-base! tw:text-left tw:sm:grid-cols-[auto_1fr] tw:sm:gap-x-3 tw:lg:flex-1"
            render(UI::Button::Component.new(color: :purple_outline, html_class: classes, aria: {expanded: false},
              data: {"registrations--show--action-panels-target": "trigger", "panel-name": panel_name,
                     action: "registrations--show--action-panels#toggle"})) do
              safe_join([
                action_icon(icon, tile:),
                content_tag(:span, title, class: "tw:mt-1.5 tw:min-w-0 tw:font-bold tw:sm:mt-0"),
                (content_tag(:span, subtitle, class: "tw:text-xs tw:opacity-60") if subtitle.present?)
              ].compact)
            end
          end

          def action_icon(icon, tile:)
            tile_bg, icon_color = case tile
            when :blue then ["tw:bg-[#e7f3fb]", "tw:text-[#016ec2]"]
            when :amber then ["tw:bg-[#fff8e1]", "tw:text-[#caa11a]"]
            else ["tw:bg-[#f0edfa]", "tw:text-[#715eb2]"]
            end
            content_tag(:span, class: "tw:flex tw:size-9 tw:items-center tw:justify-center tw:rounded-lg tw:sm:row-span-2 tw:sm:self-center #{tile_bg}") do
              helpers.inline_svg_tag("kelsey/registration_show/#{icon}.svg", class: "tw:h-[19px] tw:w-[19px] #{icon_color}")
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
            show_impound? && @staff && !impounded?
          end

          def show_update_impound?
            show_impound? && @staff && impounded?
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
