# frozen_string_literal: true

module Form
  module ComboboxManufacturer
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # Frame makers, keyed to :manufacturer_id
      def default
        render(Form::ComboboxManufacturer::Component.new)
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
