# frozen_string_literal: true

module Pages
  module Register
    module StepCombined
      # Step 2's fields on step 1's page, for the switch that asks for the whole
      # registration at once. Its submission is step 1's, carrying step 2's fields
      class Component < ApplicationComponent
        def initialize(b_param:, flow:, organization: nil, current_user: nil, motorized_review: false)
          @b_param = b_param
          @flow = flow
          @organization = organization
          @current_user = current_user
          @motorized_review = motorized_review
        end

        def render? = @flow.single_page?
      end
    end
  end
end
