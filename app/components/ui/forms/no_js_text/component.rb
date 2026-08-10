# frozen_string_literal: true

module UI
  module Forms
    module NoJsText
      # The plain text field a combobox falls back to without JavaScript. A combobox
      # submits through a hidden field only its Stimulus controller writes, so nothing
      # a rider types otherwise reaches the server.
      #
      # noscript's contents are DOM only when scripting is off - so with JavaScript this
      # renders nothing at all, and without it this is the last field of its name and
      # therefore the one Rack keeps. Pair it with a `data-js-required` wrapper around
      # the combobox, which the stylesheet below hides.
      #
      # options: shown as a datalist, which makes the textbox suggest values the way a
      # combobox would - the server resolves what's typed either way (friendly_find).
      class Component < ApplicationComponent
        def initialize(name:, label:, value: nil, options: [], required: false)
          @name = name
          @label = label
          @value = value
          @options = options
          @required = required
        end

        def call
          tag.noscript(safe_join([stylesheet, input, datalist].compact))
        end

        private

        # Ships with the field rather than the layout's head, where a noscript element
        # breaks the legacy pages' remote selectize (see the register no-JS spec)
        def stylesheet
          tag.style("[data-js-required]{display:none}".html_safe)
        end

        def input
          tag.input(type: "text", name: @name, value: @value, list: list_id,
            required: @required, class: "twinput tw:w-full", aria: {label: @label})
        end

        def datalist
          return if @options.none?

          tag.datalist(id: list_id) { safe_join(@options.map { |option| tag.option(value: option) }) }
        end

        def list_id
          "#{@name.to_s.parameterize}-no-js-options" if @options.any?
        end
      end
    end
  end
end
