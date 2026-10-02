# frozen_string_literal: true

# TODO: #4185 - remove the legacy view switch when removing the legacy org new bike iframe

module Pages
  module Org
    module RegisterSettings
      # The switches that change the shape of the organization's add-a-registration page, or send it
      # back to the legacy one
      class Component < ApplicationComponent
        def initialize(organization:, organization_admin: false, old_view: false, single_page: false,
          separate_attestation: false)
          @organization = organization
          @organization_admin = organization_admin
          @old_view = old_view
          @single_page = single_page
          @separate_attestation = separate_attestation
        end

        private

        # Nothing to leave to the registrant until the organization has rules to agree to
        def safety_rules? = @organization.registration_sequences.active.exists?

        def registration_email = @organization.auto_user&.email

        def organization_settings? = @organization_admin && registration_email.present?
      end
    end
  end
end
