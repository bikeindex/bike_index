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

        # regional_ids has no index, so each call is a seq scan - the template asks four times
        def regional_parents = @regional_parents ||= @organization.regional_parents.to_a

        def associated_organizations?
          @organization.parent_organization.present? || @organization.parent? ||
            @organization.regional? || regional_parents.any?
        end
      end
    end
  end
end
