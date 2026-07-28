# frozen_string_literal: true

module UI
  module Forms
    module ComboboxManufacturer
      class ComponentPreview < ApplicationComponentPreview
        # @!group Variants

        # Every manufacturer, keyed to :manufacturer_id, labeled by a UI::Forms::Group
        def default
          {template: "ui/forms/combobox_manufacturer/component_preview/default"}
        end

        # Limited to frame makers
        def frame_makers
          render(UI::Forms::ComboboxManufacturer::Component.new(frame_maker: true))
        end

        # Pre-selected value
        def preselected
          render(UI::Forms::ComboboxManufacturer::Component.new(value: Manufacturer.frame_makers.first&.id))
        end

        # @!endgroup
      end
    end
  end
end
