# frozen_string_literal: true

module Admin
  module OrganizationShow
    module Features
      # What the organization's paid features give it, and the organizations it's associated with.
      class Component < ApplicationComponent
        def initialize(organization:)
          @organization = organization
        end

        private

        def associated_organizations?
          @organization.parent_organization.present? || @organization.parent? ||
            @organization.regional? || @organization.regional_parents.any?
        end
      end
    end
  end
end
