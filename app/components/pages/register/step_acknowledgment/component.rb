# frozen_string_literal: true

module Pages
  module Register
    module StepAcknowledgment
      # One page of the organization's e-vehicle safety rules. Every rule has to be
      # checked before the flow moves on, so the page is agreed to as a whole.
      class Component < ApplicationComponent
        def initialize(b_param:, sequence:, step:, steps:)
          @b_param = b_param
          @sequence = sequence
          @step = step
          @steps = steps
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
          register_path(b_param_token: @b_param.id_token,
            step: BikeServices::Register.step_before(@step, steps: @steps))
        end
      end
    end
  end
end
