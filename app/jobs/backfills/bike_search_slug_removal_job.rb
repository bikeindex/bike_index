# frozen_string_literal: true

module Backfills
  # bike_search is no longer a feature, but it's still stored on these rows, and admin lists it
  # as enabled until something re-saves them
  class BikeSearchSlugRemovalJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    # Organizations last, since saving one recalculates its slugs from the other two.
    # update_all rather than update, to skip the associations job every save would enqueue
    def perform
      OrganizationFeature.where("'bike_search' = ANY(feature_slugs)")
        .update_all("feature_slugs = array_remove(feature_slugs, 'bike_search')")
      Invoice.where("child_enabled_feature_slugs @> '[\"bike_search\"]'")
        .update_all("child_enabled_feature_slugs = child_enabled_feature_slugs - 'bike_search'")
      Organization.unscoped.where("enabled_feature_slugs @> '[\"bike_search\"]'")
        .update_all("enabled_feature_slugs = enabled_feature_slugs - 'bike_search'")
    end
  end
end
