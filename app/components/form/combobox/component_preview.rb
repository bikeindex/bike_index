# frozen_string_literal: true

module Form
  module Combobox
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # Plain string options
      def default
        render(Form::Combobox::Component.new(
          name: "manufacturer",
          label: "Manufacturer",
          options: %w[Trek Giant Specialized Cannondale Surly Bianchi]
        ))
      end

      # Hash options with separate display and submitted value
      def with_values
        render(Form::Combobox::Component.new(
          name: "color",
          label: "Color",
          options: [
            {display: "Black", value: "1"},
            {display: "Blue", value: "2"},
            {display: "Red", value: "3"}
          ]
        ))
      end

      # Pre-selected value, listbox open on load
      def preselected
        render(Form::Combobox::Component.new(
          name: "manufacturer",
          label: "Manufacturer",
          value: "Surly",
          open: true,
          options: %w[Trek Giant Specialized Cannondale Surly Bianchi]
        ))
      end

      # Allows submitting a value that is not in the options list
      def free_text
        render(Form::Combobox::Component.new(
          name: "manufacturer",
          label: "Manufacturer (or type your own)",
          free_text: true,
          options: %w[Trek Giant Specialized Cannondale Surly Bianchi]
        ))
      end

      # @!endgroup
    end
  end
end
