# frozen_string_literal: true

# TODO: #4185 - remove the legacy view switch when removing the legacy org new bike iframe

module Pages
  module Org
    module RegisterSettings
      # The switches that change the shape of the organization's add-a-bike page
      class Component < ApplicationComponent
        def initialize(organization:, single_page: false, separate_attestation: false)
          @organization = organization
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
