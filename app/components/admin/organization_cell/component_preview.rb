# frozen_string_literal: true

module Admin::OrganizationCell
  class ComponentPreview < ApplicationComponentPreview
    # @group Organization Variants

    def with_organization
      render(Admin::OrganizationCell::Component.new(organization:))
    end

    def with_organization_id
      render(Admin::OrganizationCell::Component.new(organization_id: Organization.deleted.first.id))
    end

    def with_search_link
      render(Admin::OrganizationCell::Component.new(organization:, render_search: true))
    end

    def missing_organization
      render(Admin::OrganizationCell::Component.new(organization_id: 99999999))
    end

    private

    def organization
      Organization.friendly_find "hogwarts"
    end
  end
end
