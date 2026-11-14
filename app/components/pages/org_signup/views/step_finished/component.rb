# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module StepFinished
        class Component < ApplicationComponent
          def initialize(organization_signup:)
            @organization_signup = organization_signup
          end

          private

          def register_for
            case @organization_signup.kind
            when "bike_shop", "bike_manufacturer" then translation(".register_for_your_customers")
            when "school" then translation(".register_for_students")
            when "law_enforcement", "municipality" then translation(".register_for_residents")
            when "property_management" then translation(".register_for_tenants")
            else translation(".register_for_community")
            end
          end
        end
      end
    end
  end
end
