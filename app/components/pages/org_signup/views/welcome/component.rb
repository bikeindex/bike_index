# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module Welcome
        # Where an activated organization's new admin lands: what to do first.
        # return_to: where they were headed before signing up, e.g. connecting Lightspeed
        class Component < ApplicationComponent
          def initialize(organization:, current_user:, return_to: nil)
            @organization = organization
            @current_user = current_user
            @return_to = return_to
          end

          private

          def organization_id = @organization.to_param

          def registration_url = new_register_url(organization_id: @organization.slug)
        end
      end
    end
  end
end
