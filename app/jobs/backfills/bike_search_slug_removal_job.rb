# frozen_string_literal: true

module Backfills
  # bike_search is no longer a feature, but it's still stored on these rows, and admin lists it
  # as enabled until something re-saves them
  class BikeSearchSlugRemovalJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    SLUG = "bike_search"

    # Organizations last, since saving one recalculates its slugs from the other two
    def perform
      OrganizationFeature.where("? = ANY(feature_slugs)", SLUG).find_each do |organization_feature|
        organization_feature.update!(feature_slugs: organization_feature.feature_slugs - [SLUG])
      end
      Invoice.where("child_enabled_feature_slugs @> ?", [SLUG].to_json).find_each do |invoice|
        invoice.child_enabled_feature_slugs -= [SLUG]
        # A deleted organization's invoice fails validating that it has an organization
        invoice.save(validate: false)
      end
      Organization.unscoped.where("enabled_feature_slugs @> ?", [SLUG].to_json).find_each do |organization|
        organization.update(skip_update: true, updated_at: Time.current)
      end
    end
  end
end
