# frozen_string_literal: true

module Atoms
  module ShortId
    # Renders a record's short_id (see ShortIdable) as a monospace code block with a copy button.
    # Pass a record that responds to short_id, or a raw short_id string.
    class Component < ApplicationComponent
      def initialize(record: nil, short_id: nil)
        @short_id = short_id || record&.short_id
      end

      private

      def render?
        @short_id.present?
      end
    end
  end
end
