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

          def action_icon(icon, tile: :purple)
            tile_bg, icon_color = case tile
            when :blue then ["tw:bg-[#e7f3fb]", "tw:text-[#016ec2]"]
            when :amber then ["tw:bg-[#fff8e1]", "tw:text-[#caa11a]"]
            else ["tw:bg-[#f0edfa]", "tw:text-[#715eb2]"]
            end
            content_tag(:span, class: "tw:flex tw:size-9 tw:flex-none tw:items-center tw:justify-center tw:rounded-lg #{tile_bg}") do
              helpers.inline_svg_tag("kelsey/registration_show/#{icon}.svg", class: "tw:h-[19px] tw:w-[19px] #{icon_color}")
            end
          end

          def action_label(title, subtitle = nil)
            content_tag(:span, class: "tw:min-w-0") do
              rows = [content_tag(:span, title, class: "tw:block tw:font-bold")]
              rows << content_tag(:span, subtitle, class: "tw:mt-0.5 tw:block tw:text-xs tw:opacity-60") if subtitle.present?
              safe_join(rows)
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

          def impound_title
            translation(".impound")
          end

          def impound_subtitle
            translation(".record_impounding")
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
