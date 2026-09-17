# frozen_string_literal: true

# TODO: #4185 - remove the legacy view switch when removing the legacy org new bike iframe

module Pages
  module Org
    module RegisterStep1
      # The register flow's opening page on an organization's own page, with the
      # switches that change its shape below it
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, organization:, current_user: nil,
          single_page: false, separate_attestation: false)
          @b_param = b_param
          @steps = steps
          @organization = organization
          @current_user = current_user
          @single_page = single_page
          @separate_attestation = separate_attestation
        end

        private

        # The organized menu already says whose admin panel this is, so the step doesn't
        def opening_page
          component = @single_page ? Pages::Register::StepCombined::Component : Pages::Register::Step1::Component
          component.new(b_param: @b_param, steps: @steps, current_user: @current_user,
            organization: @organization, skip_heading: true)
        end

        def switches_path
          new_organization_registration_path(organization_id: @organization.to_param)
        end
      end
    end
  end
end
