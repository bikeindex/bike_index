# frozen_string_literal: true

module Backfills
  class SquashedSlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Organization.unscoped.find_each do |organization|
        next if Organization.slug_for(organization.short_name) == organization.slug
        # Only the slugs friendly_find can no longer reach; the rest move on their next save as before
        next unless organization.short_name.include?("&") || Slugifyer.slugify(organization.slug) != organization.slug

        organization.update!(previous_slug: organization.slug)
      end
      PrimaryActivity.find_each do |primary_activity|
        primary_activity.update!(slug: Slugifyer.slugify(primary_activity.slug))
      end
    end
  end
end
