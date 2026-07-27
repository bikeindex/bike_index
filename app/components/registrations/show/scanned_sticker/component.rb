# frozen_string_literal: true

module Registrations
  module Show
    module ScannedSticker
      # Shown when the viewer arrived by scanning a sticker (?scanned_id), with a
      # re-link form for viewers who are allowed to reassign the sticker
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
      end
    end
  end
end
