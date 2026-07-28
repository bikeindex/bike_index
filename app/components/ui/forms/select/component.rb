# frozen_string_literal: true

module UI
  module Forms
    module Select
      # A twinput-styled select. Rails' `select` takes its option tags and options as
      # positional arguments, so it doesn't fit UI::Forms::Input's kind contract —
      # pair this with a UI::Forms::Group block for a label.
      #
      # option_tags and options are named for select_tag: options carries Rails'
      # selected:/include_blank:/prompt:.
      class Component < ApplicationComponent
        def initialize(form_builder:, attribute:, option_tags:, options: {}, required: false, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @option_tags = option_tags
          @options = options
          @html_options = html_options.merge(
            {class: ["twinput", html_options[:class]].compact.join(" ")},
            (required ? {required: true} : {})
          )
        end

        def call
          @form_builder.select(@attribute, @option_tags, @options, @html_options)
        end
      end
    end
  end
end
