# frozen_string_literal: true

module Pages
  module MyAccount
    module OrganizationRoles
      # The my_account organization roles page: the roles a user holds, dragged into the order
      # they want them prioritized in, and which of them they view Bike Index as after logging in
      class Component < ApplicationComponent
        def initialize(organization_roles:)
          @organization_roles = organization_roles
        end

        private

        # A single role is nothing to order, so it loses the ordering copy and its drag handle
        def single_role?
          @organization_roles.size == 1
        end

        def first_organization_role
          @organization_roles.first
        end

        def first_organization
          first_organization_role.organization
        end

        # With more than one, the drag decides which is first, so the copy can't name it
        def first_organization_name
          single_role? ? first_organization.short_name : translation(".your_first_organization")
        end
      end
    end
  end
end
