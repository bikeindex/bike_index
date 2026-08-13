# frozen_string_literal: true

module Backfills
  class OrganizationLandingPageJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      # unscoped: a deleted organization can be restored, and landing_html is going away
      Organization.unscoped.where.not(landing_html: [nil, ""])
        .where.missing(:organization_landing_page).find_each do |organization|
        OrganizationLandingPage.create!(organization_id: organization.id, body: organization.landing_html)
      end

      # enabled tracks ORGANIZATIONS_WITH_LANDING_PAGES, so re-running picks up a change to it.
      # Scoped, so a deleted organization's page is disabled rather than left enabled
      enabled_ids = Organization.where(slug: LandingPages::ORGANIZATIONS).pluck(:id)
      OrganizationLandingPage.find_each do |landing_page|
        landing_page.update!(enabled: enabled_ids.include?(landing_page.organization_id))
      end
    end
  end
end
