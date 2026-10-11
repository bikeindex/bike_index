# frozen_string_literal: true

module Pages
  module Bikes
    module StolenReport
      module NextSteps
        # After the report: what it already did, what's left to improve the odds - each linked to the
        # wizard step that adds it - and the ways to spread the word
        class Component < ApplicationComponent
          Item = Data.define(:state, :label, :sub, :cta, :step)

          def initialize(bike:, stolen_record:)
            @bike = bike
            @stolen_record = stolen_record
          end

          private

          def cycle_type = @bike.type

          def city = @stolen_record.city.presence || translation(".you")

          def checklist
            [Item.new(:done, translation(".listed", bike_type: cycle_type), translation(".listed_sub"), nil, nil),
              location_item, photo_item, police_item, lock_item]
          end

          def location_item
            return Item.new(:done, translation(".location_added"), translation(".location_added_sub", city:), nil, nil) if @stolen_record.city.present?

            Item.new(:todo, translation(".add_location"), translation(".add_location_sub"), translation(".add_location_cta"), "where")
          end

          def photo_item
            if @bike.public_images.any?
              Item.new(:done, translation(".photo_added", bike_type: cycle_type), translation(".photo_added_sub"), nil, nil)
            elsif @bike.stock_photo_url.present?
              Item.new(:caveat, translation(".stock_photo_added"), translation(".stock_photo_added_sub", bike_type: cycle_type),
                translation(".add_photos"), "photos")
            else
              Item.new(:todo, translation(".add_photo", bike_type: cycle_type), translation(".add_photo_sub", bike_type: cycle_type), translation(".add_photos"), "photos")
            end
          end

          def police_item
            return Item.new(:done, translation(".police_added"), translation(".police_added_sub"), nil, nil) if @stolen_record.police_report_number.present?

            Item.new(:todo, translation(".add_police"), translation(".add_police_sub"), translation(".add_police_cta"), "police")
          end

          def lock_item
            if @stolen_record.locking_description.present? && @stolen_record.lock_defeat_description.present?
              Item.new(:done, translation(".lock_added"), translation(".lock_added_sub"), nil, nil)
            else
              Item.new(:todo, translation(".add_lock"), translation(".lock_added_sub"), translation(".add_lock_cta"), "lock")
            end
          end

          def marker_class(state)
            case state
            when :done then "tw:border-blue-600 tw:bg-blue-600 tw:text-white"
            when :caveat then "tw:border-[#ffcc33] tw:bg-[#ffcc33] tw:text-white"
            else "tw:border-gray-300 tw:bg-white tw:dark:border-gray-600 tw:dark:bg-gray-800"
            end
          end

          def share_text = translation(".share_text", bike_type: cycle_type, title: @bike.title_string, city:)

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
