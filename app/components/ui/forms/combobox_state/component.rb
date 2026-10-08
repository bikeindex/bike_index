# frozen_string_literal: true

module UI
  module Forms
    module ComboboxState
      # UI::Forms::Combobox preconfigured for picking a US state, submitting its abbreviation - or, with
      # ids: true, its State record's id, for a form field like region_record_id.
      #
      # Pass `states:` to narrow the list, in StatesAndCountries.states' {name:, abbr:} shape - a state
      # with an id: submits it. html_options (form:, value:, placeholder:, required:, etc.) are forwarded to
      # UI::Forms::Combobox::Component, which renders no label -- wrap it in a UI::Forms::Group block to
      # get one. Without JavaScript it falls back to a select.
      #
      # Each reads "Oregon (OR)", the abbreviation muted, so it can be searched for. Matching is anywhere
      # in the text, so typing also ranks an abbreviation's state first (ui/forms/combobox_state_controller.js).
      class Component < ApplicationComponent
        def initialize(name: :state, states: nil, ids: false, html_options: {})
          @name = name
          @states = states || (ids ? State.united_states.pluck(:name, :abbreviation, :id).map { |name, abbr, id| {name:, abbr:, id:} } : StatesAndCountries.states)
          @html_options = html_options
        end

        def call
          tag.div(data: {controller: "ui--forms--combobox-state"}) do
            render UI::Forms::Combobox::Component.new(name: @name, options: @states.map { option(it) }, rich_display: :inline,
              dialog_label: translation(".state"), no_js: true, html_options: @html_options)
          end
        end

        private

        def option(state)
          abbreviation = "(#{state[:abbr]})"
          {display: "#{state[:name]} #{abbreviation}", value: state[:id] || state[:abbr],
           content: safe_join([state[:name], " ", tag.span(abbreviation, class: "tw:text-gray-500")])}
        end
      end
    end
  end
end
