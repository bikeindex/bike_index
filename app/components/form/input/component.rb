# frozen_string_literal: true

module Form
  module Input
    class Component < ApplicationComponent
      KINDS = %i[text_field text_area email_field number_field].freeze

      def initialize(form_builder:, attribute:, kind: :text_field, html_options: {})
        @form_builder = form_builder
        @attribute = attribute
        @kind = KINDS.include?(kind&.to_sym) ? kind.to_sym : :text_field
        @html_options = {class: "twinput"}.merge(html_options)
      end

      def call
        @form_builder.send(@kind, @attribute, @html_options)
      end
    end
  end
end
