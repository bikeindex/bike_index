# frozen_string_literal: true

module Admin
  module Organizations
    module Show
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
            end
          end

          # Relation#count queries however loaded the relation is, and the heading asks twice
          def organization_roles_count = @organization_roles_count ||= organization_roles.count
        end
      end
    end
  end
end
