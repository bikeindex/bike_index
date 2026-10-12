# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module NextSteps
        # The end of an owner's stolen registration: what the report already did, what's left to
        # improve the odds - each linked to the edit page that adds it - and the ways to spread the
        # word. Everything Pages::Bikes::StolenChecklist lists has a place here
        class Component < ApplicationComponent
          Item = Data.define(:key, :done, :label, :sub, :cta, :href)

          # register_another_path: back into the register flow, with the organization it came through
          def initialize(bike:, stolen_record:, register_another_path:)
            @bike = bike
            @stolen_record = stolen_record
            @register_another_path = register_another_path
          end

          private

          def cycle_type = @bike.type

          def city = @stolen_record.city.presence || translation(".you")

          def checklist
            [Item.new(:listed, true, translation(".listed"), translation(".listed_sub"), nil, nil),
              serial_item, location_item, photo_item, police_item, lock_item].compact
          end

          def serial_item
            return unless serial_unknown?

            Item.new(:serial, false, translation(".add_serial"), translation(".add_serial_sub"),
              translation(".add_serial_cta"), edit_path("bike_details"))
          end

          def location_item
            if @stolen_record.street.present?
              Item.new(:location, true, translation(".location_added"), translation(".location_added_sub", city:), nil, nil)
            else
              Item.new(:location, false, translation(".add_location"), translation(".add_location_sub"),
                translation(".add_location_cta"), edit_path("theft_details", alert_offered: true))
            end
          end

          def photo_item
            if @bike.public_images.any?
              Item.new(:photo, true, translation(".photo_added", bike_type: cycle_type), translation(".photo_added_sub"), nil, nil)
            else
              Item.new(:photo, false, translation(".add_photo", bike_type: cycle_type),
                translation(".add_photo_sub", bike_type: cycle_type), translation(".add_photos"), edit_path("photos"))
            end
          end

          def police_item
            if police_report?
              Item.new(:police, true, translation(".police_added"), nil, nil, nil)
            else
              Item.new(:police, false, translation(".add_police"), nil, translation(".add_police_cta"),
                edit_path("theft_details", alert_offered: true, anchor: "policeReportNumber"))
            end
          end

          def lock_item
            done = @stolen_record.locking_description.present? && @stolen_record.lock_defeat_description.present?
            Item.new(:lock, done, done ? translation(".lock_added") : translation(".add_lock"), translation(".lock_sub"),
              (translation(".add_lock_cta") unless done), (edit_path("theft_details", alert_offered: true) unless done))
          end

          def marker_class(done)
            done ? "tw:border-blue-600 tw:bg-blue-600 tw:text-white" : "tw:border-gray-300 tw:bg-white tw:dark:border-gray-600 tw:dark:bg-gray-800"
          end

          def serial_unknown? = @bike.serial_unknown?

          def police_report? = @stolen_record.police_report_number.present?

          # The police services need a serial to search on, so a report without one isn't sent
          def submitted_to_police_services? = police_report? && !serial_unknown?

          # Only the Netherlands has reporting instructions we can give
          def netherlands_instructions? = !police_report? && @stolen_record.country == Country.netherlands

          def theft_alert? = @stolen_record.theft_alerts.any?

          def edit_path(template, **) = edit_bike_path(@bike, edit_template: template, **)

          def share_text = translation(".share_text", title: @bike.title_string, city:)

          def share_url = bike_url(@bike)

          def facebook_url = "https://www.facebook.com/sharer/sharer.php?#{{u: share_url}.to_query}"

          def nextdoor_url = "https://nextdoor.com/sharekit/?#{{source: "bikeindex", body: "#{share_text} #{share_url}"}.to_query}"

          def cheapest_plan
            @cheapest_plan ||= TheftAlertPlan.active.in_language(I18n.locale).price_ordered_asc.first
          end

          def organization_stolen_message?
            @stolen_record.organization_stolen_message&.shown_to?(@stolen_record)
          end
        end
      end
    end
  end
end
