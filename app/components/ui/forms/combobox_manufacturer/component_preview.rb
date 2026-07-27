# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturer
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        # Autocompletes every manufacturer, keyed to :manufacturer_id and labeled by a
        # UI::Forms::Group. An unindexed manufacturer is entered through the
        # "Unknown manufacturer" option
        def default
          {template: "ui/forms/combobox_manufacturer/component_preview/default"}
        end

        # Limited to manufacturers that make frames
        def frame_makers
          render(UI::Forms::ComboboxManufacturer::Component.new(frame_maker: true))
        end

        # Only an indexed manufacturer is selectable
        def no_manufacturer_other
          render(UI::Forms::ComboboxManufacturer::Component.new(no_manufacturer_other: true))
        end

        # Pre-selected manufacturer
        def preselected
          render(UI::Forms::ComboboxManufacturer::Component.new(
            form: bike_form("preselected_bike", Bike.new(manufacturer: Manufacturer.frame_makers.first))
          ))
        end

        # How a record with Manufacturer.other renders - its manufacturer_other is
        # displayed, since Manufacturer.other isn't selectable
        def unknown_manufacturer
          render(UI::Forms::ComboboxManufacturer::Component.new(
            form: bike_form("unknown_bike", Bike.new(manufacturer: Manufacturer.other, manufacturer_other: "Bikes by Seth"))
          ))
        end

        # @!endgroup

        private

        # The combobox ids come from the form's object name, so each variant needs its
        # own - they render together on the group page
        def bike_form(object_name, bike)
          ActionView::Helpers::FormBuilder.new(object_name, bike, template, {})
        end
      end
    end
  end
end
