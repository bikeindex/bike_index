# frozen_string_literal: true

module Admin::OrganizationCell
  class ComponentPreview < ApplicationComponentPreview
    # @group Organization Variants

    def with_organization
      organization = Organization.first || FactoryBot.create(:organization)
      render(Admin::OrganizationCell::Component.new(organization:))
    end

    def with_organization_id
      organization = Organization.first || FactoryBot.create(:organization)
      render(Admin::OrganizationCell::Component.new(organization_id: organization.id))
    end

    def with_search_link
      organization = Organization.first || FactoryBot.create(:organization)
      render(Admin::OrganizationCell::Component.new(organization:, render_search: true))
    end

    def missing_organization
      render(Admin::OrganizationCell::Component.new(organization_id: 99999999))
    end
  end
end
