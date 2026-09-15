# frozen_string_literal: true

module SharedBlocks
  module Honeypot
    # `additional` coming back is what User#looks_like_spam?, Feedback#looks_like_spam?
    # and BikeServices::Register flag a submission on
    class Component < ApplicationComponent
      FIELD_OPTIONS = {tabindex: -1, autocomplete: "off"}.freeze

      # Without a form_builder the field posts as `additional` rather than scoped to a model
      def initialize(form_builder: nil)
        @form_builder = form_builder
      end

      def call
        tag.div(class: "tw:hidden") { safe_join([label, field]) }
      end

      private

      def label
        return @form_builder.label(:additional, "Additional") if @form_builder.present?

        helpers.label_tag(:additional, "Additional")
      end

      def field
        return @form_builder.text_field(:additional, **FIELD_OPTIONS) if @form_builder.present?

        helpers.text_field_tag(:additional, nil, **FIELD_OPTIONS)
      end
    end
  end
end
