# frozen_string_literal: true

module Pages
  module Register
    module StepCombined
      # Step 1 and step 2 on one page, for the switch that asks for the whole
      # registration at once. Its submission is step 1's, carrying step 2's fields
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, current_user: nil, skip_heading: false, organization: nil,
          motorized_review: false)
          @b_param = b_param
          @steps = steps
          @current_user = current_user
          @skip_heading = skip_heading
          @organization = organization
          @motorized_review = motorized_review
        end

        private

        def organization
          @organization ||= @b_param.creation_organization
        end
      end
    end
  end
end
