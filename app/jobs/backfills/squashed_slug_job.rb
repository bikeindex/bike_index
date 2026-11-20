# frozen_string_literal: true

module Backfills
  class SquashedSlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Organization.unscoped.find_each do |organization|
        next if Organization.slug_for(organization.short_name) == organization.slug

        # Lookups slugify what they're given, so a previous slug only matches in slugified form
        organization.update!(previous_slug: Slugifyer.slugify(organization.slug))
      end
      # FriendlySlugFindable only sets slug on create
      [Cgroup, ContentTag, Ctype, FrontGearType, LockType, PrimaryActivity, RearGearType].each do |klass|
        klass.find_each { it.update!(slug: Slugifyer.slugify(it.slug)) }
      end
      Manufacturer.find_each do |manufacturer|
        next if Slugifyer.slugify(manufacturer.name) == manufacturer.slug

        manufacturer.update!(previous_slugs: [*manufacturer.previous_slugs, Slugifyer.slugify(manufacturer.slug)])
      end
    end
  end
end
