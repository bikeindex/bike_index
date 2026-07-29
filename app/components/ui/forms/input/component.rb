# frozen_string_literal: true

module UI
  module Forms
    module Input
      class Component < ApplicationComponent
        # Every kind takes (attribute, html_options) — a select doesn't, so it's
        # UI::Forms::Select instead. No email either: an email field is UI::Forms::Email,
        # which asks for the type itself so that every one of them checks for a typo.
        KINDS = %i[text_field text_area number_field telephone_field datetime_local_field].freeze

        # UI::Forms::Group forwards a kind here, so it validates through this too
        def self.validate_kind!(kind)
          return kind.to_sym if KINDS.include?(kind&.to_sym)

          raise ArgumentError, "unknown kind #{kind.inspect}, expected one of: #{KINDS.join(", ")}"
        end

        def initialize(form_builder:, attribute:, kind: :text_field, required: false, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @kind = self.class.validate_kind!(kind)
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
