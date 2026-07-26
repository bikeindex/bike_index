# frozen_string_literal: true

module UI
  module Forms
    module Input
      class Component < ApplicationComponent
        # Every kind takes (attribute, html_options) — a select doesn't, so it's
        # UI::Forms::Select instead.
        KINDS = %i[text_field text_area email_field number_field telephone_field datetime_local_field].freeze

        def initialize(form_builder:, attribute:, kind: :text_field, required: false, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = KINDS.include?(kind&.to_sym) ? kind.to_sym : :text_field
          @html_options = html_options.merge(
            {class: ["twinput", html_options[:class]].compact.join(" ")},
            (required ? {required: true} : {})
          )
        end

        def call
          @form_builder.send(@kind, @attribute, @html_options)
        end
      end
    end
  end
end
