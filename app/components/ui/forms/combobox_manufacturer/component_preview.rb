# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturer
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        # Autocompletes every manufacturer, keyed to :manufacturer_id. A manufacturer
        # that isn't indexed is entered through the "Unknown manufacturer" option
        def default
          render(UI::Forms::ComboboxManufacturer::Component.new)
        end

        # Limited to manufacturers that make frames
        def frame_makers
          render(UI::Forms::ComboboxManufacturer::Component.new(frame_maker: true))
        end

        # Only an indexed manufacturer is selectable
        def no_manufacturer_other
          render(UI::Forms::ComboboxManufacturer::Component.new(no_manufacturer_other: true))
        end

        # Pre-selected manufacturer, custom label
        def preselected
          render(UI::Forms::ComboboxManufacturer::Component.new(
            label: "Frame manufacturer",
            form: bike_form(Bike.new(manufacturer: Manufacturer.frame_makers.first))
          ))
        end

        # How a record with Manufacturer.other renders - its manufacturer_other is
        # displayed, since Manufacturer.other isn't selectable
        def unknown_manufacturer
          render(UI::Forms::ComboboxManufacturer::Component.new(
            form: bike_form(Bike.new(manufacturer: Manufacturer.other, manufacturer_other: "Bikes by Seth"))
          ))
        end

        # @!endgroup

        private

        def bike_form(bike)
          ActionView::Helpers::FormBuilder.new("bike", bike, template, {})
        end
      end
    end
  end
end
