# frozen_string_literal: true

module Pages
  module Register
    module StepAcknowledgmentReview
      # The last of the e-vehicle pages: what was acknowledged, and the acknowledgment
      # binding the registrant to it
      class Component < ApplicationComponent
        def initialize(b_param:, sequence:, steps:, current_user: nil)
          @b_param = b_param
          @sequence = sequence
          @steps = steps
          @current_user = current_user
        end

        private

        def pages
          @pages ||= BikeServices::Register.sequence_pages(@sequence)
        end

        # The review is the last acknowledgment step, so it's both the number and the total
        def acknowledgment_step_count
          @acknowledgment_step_count ||= BikeServices::Register.acknowledgment_step_count(@sequence)
        end

        def page_path(index)
          register_path(b_param_token: @b_param.id_token,
            step: BikeServices::Register.step_for_page_index(index))
        end

        def previous_path
          page_path(pages.count - 1)
        end

        # Who's agreeing: their account name, falling back to the address the
        # registration is going to
        # Whoever the registration is for, not whoever is filling it in - step 2 asks for
        # a name exactly when the two differ, so it wins over the signed-in account's
        def registrant_name
          @b_param.user_name.presence || @current_user&.name.presence || @b_param.owner_email
        end
      end
    end
  end
end
