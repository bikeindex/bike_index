# frozen_string_literal: true

module Backfills
  class OrganizationLandingPageJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      # Scoped, so a deleted organization's page is disabled rather than left enabled
      enabled_organization_ids = Organization.where(slug: LandingPages::ORGANIZATIONS).pluck(:id)

      # unscoped: a deleted organization can be restored, and landing_html is going away
      Organization.unscoped.where.not(landing_html: [nil, ""])
        .where.missing(:organization_landing_page).find_each do |organization|
        OrganizationLandingPage.create!(organization_id: organization.id, body: organization.landing_html,
          enabled: enabled_organization_ids.include?(organization.id))
      end

      # Re-running is how an ORGANIZATIONS_WITH_LANDING_PAGES change gets applied
      OrganizationLandingPage.where(enabled: true).where.not(organization_id: enabled_organization_ids)
        .find_each { |landing_page| landing_page.update!(enabled: false) }
      OrganizationLandingPage.where(enabled: false, organization_id: enabled_organization_ids)
        .find_each { |landing_page| landing_page.update!(enabled: true) }
    end
  end
end
