# frozen_string_literal: true

module Form
  module Group
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, kind: :text_field, label_text: nil, html_options: {})
        @form_builder = form_builder
        @attribute = attribute
        @kind = kind
        @label_text = label_text || attribute.to_s.humanize
        @html_options = html_options
      end

      private

      def check_box?
        @kind.to_sym == :check_box
      end
    end
  end
end
