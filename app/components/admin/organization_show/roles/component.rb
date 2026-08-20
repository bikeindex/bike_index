# frozen_string_literal: true

module Admin
  module OrganizationShow
    module Roles
      # The organization's roles, with the deleted ones behind a toggle.
      class Component < ApplicationComponent
        def initialize(organization:, deleted:)
          @organization = organization
          @deleted = deleted
        end

        private

        def organization_roles
          return @organization.organization_roles.deleted.reorder(deleted_at: :asc) if @deleted

          @organization.organization_roles.reorder(created_at: :asc)
        end
      end
    end
  end
end
