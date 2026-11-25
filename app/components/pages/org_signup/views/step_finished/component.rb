# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module StepFinished
        class Component < ApplicationComponent
          def initialize(organization_signup:, current_user: nil)
            @organization_signup = organization_signup
            @current_user = current_user
          end

          private

          def exhausted? = OrgServices::Signup.confirmation_emails_exhausted?(@organization_signup)

          # Signed in, step 1 has no email field to change it in - and past the cap, a new
          # address couldn't be sent a link anyway
          def change_email? = @current_user.blank? && !exhausted?

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
