# frozen_string_literal: true

module Form
  module ComboboxManufacturer
    # Form::Combobox preconfigured for picking a Manufacturer.
    #
    # Defaults `name` to :manufacturer_id and the options to frame makers; pass a
    # different `manufacturers` relation to widen the list. Every other keyword
    # (form:, label:, value:, required:, include_blank:, placeholder:, etc.) is
    # forwarded to Form::Combobox::Component.
    class Component < ApplicationComponent
      def initialize(name: :manufacturer_id, manufacturers: Manufacturer.frame_makers, **combobox_options)
        @name = name
        @manufacturers = manufacturers
        @combobox_options = combobox_options
      end

      def call
        render Form::Combobox::Component.new(
          name: @name,
          label: Manufacturer.model_name.human,
          options: @manufacturers.pluck(:name, :id),
          **@combobox_options
        )
      end
    end
  end
end
