# frozen_string_literal: true

module Admin::OrganizationCell
  class Component < ApplicationComponent
    def initialize(organization: nil, organization_id: nil, render_search: false)
      @organization = organization
      @organization_id = organization_id || organization&.id
      @render_search = render_search
    end

    def organization_present?
      @organization_id.present?
    end

    def organization_subject
      return @organization if @organization.present?
      Organization.unscoped.find_by(id: @organization_id) if @organization_id.present?
    end
  end
end
