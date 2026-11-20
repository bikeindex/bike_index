# frozen_string_literal: true

module Backfills
  class SquashedSlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Organization.unscoped.find_each do |organization|
        next if Organization.slug_for(organization.short_name) == organization.slug
        # Only slugs friendly_find can no longer reach
        next unless organization.short_name.include?("&") || Slugifyer.slugify(organization.slug) != organization.slug

        organization.update!(previous_slug: organization.slug)
      end
      # FriendlySlugFindable only sets slug on create
      [Cgroup, ContentTag, Ctype, FrontGearType, LockType, PrimaryActivity, RearGearType].each do |klass|
        klass.find_each { it.update!(slug: Slugifyer.slugify(it.slug)) }
      end
      # A save moves the old slug into previous_slugs
      Manufacturer.find_each { it.save! if Slugifyer.slugify(it.slug) != it.slug }
    end
  end
end
