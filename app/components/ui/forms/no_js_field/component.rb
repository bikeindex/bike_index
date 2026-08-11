# frozen_string_literal: true

module UI
  module Forms
    module NoJsField
      # The plain control a combobox falls back to without JavaScript, since a combobox
      # submits through a hidden field only its Stimulus controller writes.
      #
      # noscript's contents are DOM only when scripting is off, where this is the last
      # field of its name and so the one Rack keeps. Pair it with a `data-js-required`
      # wrapper around the combobox, which the stylesheet below hides.
      #
      # A select by default - it posts the option's own value and can't be mistyped. text:
      # for the comboboxes a list can't serve (see UI::Forms::Combobox::Component), where
      # the options become a datalist of suggestions instead.
      class Component < ApplicationComponent
        # [display, value] pairs, the shape options_for_select takes
        def initialize(name:, label:, value: nil, options: [], required: false, text: false)
          @name = name
          @label = label
          @value = value
          @options = options
          @required = required
          @text = text
        end

        def call
          tag.noscript(safe_join([stylesheet, field, datalist].compact))
        end

        private

        # Not the layout's head, where a noscript element coincided with the legacy pages'
        # remote selectize failing to open - unexplained, so keep it out until it isn't
        def stylesheet
          tag.style("[data-js-required]{display:none}".html_safe)
        end

        def field
          @text ? text_input : select
        end

        def text_input
          tag.input(type: "text", name: @name, value: @value, list: list_id,
            required: @required, class: "twinput tw:w-full", aria: {label: @label})
        end

        # A blank first option, so a required select can't quietly submit whichever sorts first
        def select
          helpers.select_tag(@name, helpers.options_for_select(@options, @value.to_s),
            include_blank: true, required: @required, class: "twinput tw:w-full", aria: {label: @label})
        end

        def datalist
          return if list_id.blank?

          tag.datalist(id: list_id) do
            safe_join(@options.map { |display, _value| tag.option(value: display) })
          end
        end

        def list_id
          "#{@name.to_s.parameterize}-no-js-options" if @text && @options.any?
        end
      end
    end
  end
end
