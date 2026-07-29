# frozen_string_literal: true

module Register
  module StepReview
    # The last of the e-vehicle pages: what was acknowledged, and the attestation
    # binding the registrant to it
    class Component < ApplicationComponent
      def initialize(b_param:, sequence:, current_user: nil)
        @b_param = b_param
        @sequence = sequence
        @current_user = current_user
      end

      private

      def pages
        @pages ||= BikeServices::Register.sequence_pages(@sequence)
      end

      def total_steps
        @total_steps ||= BikeServices::Register.total_steps(@sequence)
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
      def registrant_name
        @current_user&.name.presence || @b_param.owner_email
      end
    end
  end
end
