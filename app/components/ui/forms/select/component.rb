# frozen_string_literal: true

module UI
  module Forms
    module Select
      # A twinput-styled select. Rails' `select` takes its choices and options as
      # positional arguments, so it doesn't fit UI::Forms::Input's kind contract —
      # pair this with UI::Forms::Group (kind: :content_block) for a label.
      #
      # select_options carries Rails' selected:/include_blank:/prompt:.
      class Component < ApplicationComponent
        def initialize(form_builder:, attribute:, choices:, select_options: {}, required: false, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @choices = choices
          @select_options = select_options
          @html_options = html_options.merge(
            {class: ["twinput tw:mt-1", html_options[:class]].compact.join(" ")},
            (required ? {required: true} : {})
          )
        end

        def call
          @form_builder.select(@attribute, @choices, @select_options, @html_options)
        end
      end
    end
  end
end
