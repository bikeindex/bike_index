# frozen_string_literal: true

module UI
  module Forms
    module Input
      class Component < ApplicationComponent
        KINDS = %i[text_field text_area email_field number_field telephone_field datetime_local_field select].freeze

        # For select, pass `choices` (and `select_options` for selected:/include_blank:).
        # `html_options[:class]` is appended to twinput rather than replacing it.
        def initialize(form_builder:, attribute:, kind: :text_field, required: false, choices: nil, select_options: {}, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = KINDS.include?(kind&.to_sym) ? kind.to_sym : :text_field
          @choices = choices
          @select_options = select_options
          @html_options = html_options.merge(
            {class: ["twinput", html_options[:class]].compact.join(" ")},
            (required ? {required: true} : {})
          )
        end

        def call
          if @kind == :select
            @form_builder.select(@attribute, @choices, @select_options, @html_options)
          else
            @form_builder.send(@kind, @attribute, @html_options)
          end
        end
      end
    end
  end
end
