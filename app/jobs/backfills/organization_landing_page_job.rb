# frozen_string_literal: true

module Backfills
  class OrganizationLandingPageJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      # Scoped, so a deleted organization's page is disabled rather than left enabled
      enabled_organization_ids = Organization.where(slug: LandingPages::ORGANIZATIONS).pluck(:id)

      # Re-running is how an ORGANIZATIONS_WITH_LANDING_PAGES change gets applied
      OrganizationLandingPage.where(enabled: true).where.not(organization_id: enabled_organization_ids)
        .find_each { |landing_page| landing_page.update!(enabled: false) }
      OrganizationLandingPage.where(enabled: false, organization_id: enabled_organization_ids)
        .find_each { |landing_page| landing_page.update!(enabled: true) }
    end
  end
end
