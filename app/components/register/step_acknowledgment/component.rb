# frozen_string_literal: true

module Register
  module StepAcknowledgment
    # One page of the organization's e-vehicle safety rules. Every rule has to be
    # checked before the flow moves on, so the page is agreed to as a whole.
    class Component < ApplicationComponent
      def initialize(b_param:, sequence:, step:)
        @b_param = b_param
        @sequence = sequence
        @step = step
      end

      private

      def pages
        @pages ||= BikeServices::Register.sequence_pages(@sequence)
      end

      def position
        BikeServices::Register.page_index_for_step(@step)
      end

      def page
        pages[position]
      end

      # The first page is where the flow explains why these pages appeared at all
      def first?
        position.zero?
      end

      # Revisiting a page from the review shows what was agreed to, rather than
      # asking for it again
      def acknowledged?
        BikeServices::Register.acknowledged_page_ids(@b_param).include?(page.id)
      end

      def previous_path
        return register_path(b_param_token: @b_param.id_token, step: 2) if first?

        register_path(b_param_token: @b_param.id_token,
          step: BikeServices::Register.step_for_page_index(position - 1))
      end

      def organization_name
        @sequence.organization&.short_name
      end
    end
  end
end
