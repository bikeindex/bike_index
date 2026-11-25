# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module ScannedSticker
          # Shown when the viewer arrived by scanning a sticker (?scanned_id), with a re-link
          # form for anyone allowed to reassign it
          class Component < ApplicationComponent
            def initialize(bike:, bike_sticker: nil, current_user: nil)
              @bike = bike
              @bike_sticker = bike_sticker
              @current_user = current_user
            end

            def render?
              @bike_sticker.present?
            end

            private

            def relinkable?
              @current_user&.authorized?(@bike_sticker)
            end

            def update_sticker_path
              bike_sticker_path(id: @bike_sticker.code, organization_id: @bike_sticker.organization_id)
            end

            def qr_icon
              helpers.inline_svg_tag("icons/qr-code.svg", class: "tw:h-4 tw:w-4", aria_hidden: true)
            end
          end
        end
      end
    end
  end
end
