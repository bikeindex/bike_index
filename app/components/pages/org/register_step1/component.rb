# frozen_string_literal: true

# TODO: #4185 - remove the legacy view switch when removing the legacy org new bike iframe

module Pages
  module Org
    module RegisterStep1
      # The register flow's opening page on an organization's own page, with the
      # switches that change its shape below it
      class Component < ApplicationComponent
        def initialize(b_param:, flow:, organization:, current_user: nil, separate_attestation: false,
          motorized_review: false)
          @b_param = b_param
          @flow = flow
          @organization = organization
          @current_user = current_user
          @separate_attestation = separate_attestation
          @motorized_review = motorized_review
        end

        private

        # Nothing to leave to the registrant until the organization has rules to agree to.
        # Through the association, since a bare RegistrationSequence here is Pages::Org's
        def safety_rules? = @organization.registration_sequences.active.exists?

        def switches_path
          switches_organization_registrations_path(organization_id: @organization.to_param)
        end
      end
    end
  end
end
