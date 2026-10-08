# frozen_string_literal: true

# TODO: #4185 - remove the legacy view switch when removing the legacy org new bike iframe

module Pages
  module Org
    module RegisterSettings
      # The switches that change the shape of the organization's add-a-registration page, or send it
      # or the unregistered notification page back to the legacy one
      class Component < ApplicationComponent
        def initialize(organization:, old_view: false, old_unregistered_notification_view: false, single_page: false,
          separate_attestation: false)
          @organization = organization
          @old_view = old_view
          @old_unregistered_notification_view = old_unregistered_notification_view
          @single_page = single_page
          @separate_attestation = separate_attestation
        end

        private

        # Nothing to leave to the registrant until the organization has rules to agree to
        def safety_rules? = @organization.registration_sequences.active.exists?
      end
    end
  end
end
