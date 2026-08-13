# frozen_string_literal: true

module Backfills
  class OrganizationLandingPageJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      # unscoped: a deleted organization can be restored
      Organization.unscoped.where.not(landing_html: [nil, ""])
        .where.missing(:organization_landing_page).find_each do |organization|
        # enabled matches today's routing gate, so nothing new goes live
        OrganizationLandingPage.create!(organization_id: organization.id, body: organization.landing_html,
          enabled: LandingPages::ORGANIZATIONS.include?(organization.slug))
      end
    end
  end
end
