# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturer
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        # Every manufacturer, keyed to :manufacturer_id
        def default
          render(UI::Forms::ComboboxManufacturer::Component.new)
        end

        # Limited to frame makers
        def frame_makers
          render(UI::Forms::ComboboxManufacturer::Component.new(frame_maker: true))
        end

        # Pre-selected value, custom label
        def preselected
          render(UI::Forms::ComboboxManufacturer::Component.new(
            label: "Frame manufacturer",
            value: Manufacturer.frame_makers.first&.id
          ))
        end

        # @!endgroup
      end
    end
  end
end
