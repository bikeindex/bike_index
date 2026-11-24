# frozen_string_literal: true

module Backfills
  class SquashedSlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      skipped_ids = Organization.unscoped.find_each.filter_map do |organization|
        next if Organization.slug_for(organization.short_name) == organization.slug

        # Lookups slugify what they're given, so a previous slug only matches in slugified form -
        # and when that's the new slug, lookups already reach it
        previous_slug = Slugifyer.slugify(organization.slug)
        saved = Organization.transaction do
          organization.save!
          next true if !organization.slug_previously_changed? || organization.slug == previous_slug
          # previous_slug holds one value - overwriting it would break the older URL
          raise ActiveRecord::Rollback if organization.previous_slug.present? && organization.previous_slug != previous_slug

          organization.update_column(:previous_slug, previous_slug)
        end
        organization.id unless saved
      end
      # FriendlySlugFindable only sets slug on create
      [Cgroup, ContentTag, Ctype, FrontGearType, LockType, PrimaryActivity, RearGearType].each do |klass|
        klass.find_each do |record|
          slug = Slugifyer.slugify(record.slug)
          record.update!(slug:) unless slug == record.slug
        end
      end
      Manufacturer.find_each do |manufacturer|
        next if Slugifyer.slugify(manufacturer.name) == manufacturer.slug

        manufacturer.save!
      end
      raise "Skipped organizations with a previous_slug: #{skipped_ids.join(", ")}" if skipped_ids.any?
    end
  end
end
