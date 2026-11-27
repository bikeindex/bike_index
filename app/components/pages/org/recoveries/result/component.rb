# frozen_string_literal: true

module Pages
  module Org
    module Recoveries
      module Result
        # One recovery in the recoveries page's list or cards view, linked to its bike
        class Component < ApplicationComponent
          def initialize(stolen_record:, organization:, distance_text:, organized:, result_view:)
            @stolen_record = stolen_record
            @bike = stolen_record.bike
            @organization = organization
            @distance_text = distance_text
            @organized = organized
            @cards = result_view == :cards
          end

          private

          def bike_href = bike_path(@bike, organization_id: @organization.to_param)

          def thumb_image_url
            @thumb_image_url ||= BikeServices::Displayer.thumb_image_url(@bike)
          end

          def location
            @location ||= @stolen_record.formatted_address_string(visible_attribute: :postal_code)
          end

          def recovered_badge
            UI::Badge::Component.new(text: translation(".recovered"), color: :success)
          end
        end
      end
    end
  end
end
