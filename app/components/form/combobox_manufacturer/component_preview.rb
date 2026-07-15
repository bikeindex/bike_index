# frozen_string_literal: true

module Form
  module ComboboxManufacturer
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # Every manufacturer, keyed to :manufacturer_id
      def default
        render(Form::ComboboxManufacturer::Component.new)
      end

      # Limited to frame makers
      def frame_makers
        render(Form::ComboboxManufacturer::Component.new(frame_maker: true))
      end

      # Pre-selected value, custom label
      def preselected
        render(Form::ComboboxManufacturer::Component.new(
          label: "Frame manufacturer",
          value: Manufacturer.frame_makers.first&.id
        ))
      end

      # @!endgroup
    end
  end
end
