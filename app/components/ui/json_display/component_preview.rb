# frozen_string_literal: true

module UI
  module JsonDisplay
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      def default
        render(UI::JsonDisplay::Component.new(data: sample_data))
      end

      def small
        render(UI::JsonDisplay::Component.new(data: sample_data, small: true))
      end

      def max_width
        render(UI::JsonDisplay::Component.new(data: sample_data, max_width: 300, small: true))
      end

      # @!endgroup

      private

      def sample_data
        {
          bike: {
            manufacturer_id: 82,
            cycle_type: "cargo",
            serial_number: "GULLY-1987-XX",
            primary_frame_color_id: 4,
            owner_email: "mothman@bikeindex.org",
            components: [{ctype: "headlight", description: "unusually bright"}]
          },
          origin: "register_flow",
          revised_new: true,
          stolen_record: nil
        }
      end
    end
  end
end
