# frozen_string_literal: true

module UI
  module Forms
    module ComboboxState
      # UI::Forms::Combobox preconfigured for picking a US state, submitting its abbreviation.
      #
      # Pass `states:` to narrow the list, in StatesAndCountries.states' {name:, abbr:} shape.
      # input_class: and html_options (form:, value:, placeholder:, etc.) are forwarded to
      # UI::Forms::Combobox::Component, which renders no label -- wrap it in a
      # UI::Forms::Group block to get one. Without JavaScript it falls back to a select.
      #
      # Each reads "Oregon (OR)", the abbreviation muted, so it can be searched for. Matching is anywhere
      # in the text, so typing also ranks an abbreviation's state first (ui/forms/combobox_state_controller.js).
      class Component < ApplicationComponent
        def initialize(name: :state, states: StatesAndCountries.states, input_class: nil, html_options: {})
          @name = name
          @states = states
          @input_class = input_class
          @html_options = html_options
        end

        def call
          tag.div(data: {controller: "ui--forms--combobox-state"}) do
            render UI::Forms::Combobox::Component.new(name: @name, options: @states.map { option(it) }, rich_display: :inline,
              no_js: true, input_class: @input_class, html_options: @html_options)
          end
        end

        private

        def option(state)
          abbreviation = "(#{state[:abbr]})"
          {display: "#{state[:name]} #{abbreviation}", value: state[:abbr],
           content: safe_join([state[:name], " ", tag.span(abbreviation, class: "tw:text-gray-500")])}
        end
      end
    end
  end
end
