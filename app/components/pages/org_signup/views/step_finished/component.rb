# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module StepFinished
        # Everything's entered - the organization is created by the emailed link
        class Component < ApplicationComponent
          def initialize(organization_signup:)
            @organization_signup = organization_signup
          end
        end
      end
    end
  end
end
