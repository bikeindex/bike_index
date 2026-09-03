# frozen_string_literal: true

module UI
  module JsonDisplay
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      def default
        render(UI::JsonDisplay::Component.new(data: sample_data))
      end

      def small_with_max_width
        render(UI::JsonDisplay::Component.new(data: sample_data, max_width: 300, small: true))
      end

      # Drops the nil and empty values, keeping false ones
      def skip_blank
        render(UI::JsonDisplay::Component.new(data: sample_data, skip_blank: true))
      end

      # @!endgroup

      private

      def sample_data
        {
          bike: {
            manufacturer_id: 82,
            cycle_type: "cargo",
            serial_number: "GULLY-1987-XX",
            owner_email: "mothman@bikeindex.org"
          },
          origin: "register_flow",
          revised_new: false,
          stolen_record: nil,
          bike_sticker: ""
        }
      end
    end
  end
end
