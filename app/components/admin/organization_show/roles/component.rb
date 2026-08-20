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
          @organization_roles ||= if @deleted
            @organization.organization_roles.deleted.reorder(deleted_at: :asc)
          else
            @organization.organization_roles.reorder(created_at: :asc)
          end.load
        end
      end
    end
  end
end
