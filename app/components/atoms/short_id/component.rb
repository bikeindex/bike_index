# frozen_string_literal: true

module Atoms
  module ShortId
    # Renders a record's short_id (see ShortIdable) as a monospace code block.
    # Pass a record that responds to short_id, or a raw short_id string.
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:font-mono tw:text-sm tw:p-0 tw:bg-transparent tw:text-inherit tw:rounded-none"

      def initialize(record: nil, short_id: nil, html_class: nil)
        @short_id = short_id || record&.short_id
        @html_class = html_class
      end

      def call
        content_tag(:code, @short_id, class: [BASE_CLASSES, @html_class].compact.join(" "))
      end

      private

      def render?
        @short_id.present?
      end
    end
  end
end
