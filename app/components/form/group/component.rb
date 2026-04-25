# frozen_string_literal: true

module Form
  module Group
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, kind: :text_field, label_text: nil, html_options: {}, entries: [], selected: nil)
        @form_builder = form_builder
        @attribute = attribute
        @kind = kind
        @label_text = label_text || attribute.to_s.humanize
        @html_options = html_options
        @entries = entries
        @selected = selected
      end

      def radio_button_group?
        @kind.to_sym == :radio_button_group
      end
    end
  end
end
