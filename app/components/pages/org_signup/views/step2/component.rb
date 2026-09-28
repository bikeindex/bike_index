# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module Step2
        # Where the organization is. Its activation link went out with step 1
        class Component < ApplicationComponent
          def initialize(organization_signup:)
            @organization_signup = organization_signup
          end
        end
      end
    end
  end
end
