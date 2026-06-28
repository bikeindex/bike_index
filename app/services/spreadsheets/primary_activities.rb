# frozen_string_literal: true

require "csv"

module Spreadsheets
  module PrimaryActivities
    extend Functionable

    EXPORT_COLUMNS = %i[flavor families].freeze

    def to_csv(primary_activities = nil)
      primary_activities ||= PrimaryActivity.by_priority

      CSV.generate do |csv|
        csv << EXPORT_COLUMNS
        names_and_families(primary_activities).each { csv << it }
      end
    end

    def import(csv)
      CSV.foreach(csv, headers: true, header_converters: :symbol) do |row|
        update_or_create_for!(row)
      end
    end

    #
    # private below here
    #

    def names_and_families(primary_activities)
      flavors_families = {}

      primary_activities.flavor.each do |primary_activity|
        family_name = primary_activity.top_level? ? nil : primary_activity.family_name
        flavors_families[primary_activity.name] ||= family_name
        next if flavors_families[primary_activity.name] == family_name

        # If the name wasn't assigned in this block, add it
        flavors_families[primary_activity.name] += " & #{family_name}"
      end

      flavors_families.to_a
    end

    def update_or_create_for!(row)
      family_ids = row[:families].presence&.split("&")&.map do |name|
        upsert!(PrimaryActivity.family, name, family: true).id
      end
      return if row[:flavor].blank?

      (family_ids || [nil]).each do |primary_activity_family_id|
        # Top-level flavors self-reference their id, so nil never matches them
        scope = primary_activity_family_id ? PrimaryActivity.where(primary_activity_family_id:) : PrimaryActivity.flavor.top_level
        upsert!(scope, row[:flavor], primary_activity_family_id:, family: false)
      end
    end

    # Find by exact slug and correct the stored name, or create. Slug, not friendly_find, keeps re-imports idempotent
    def upsert!(scope, name, **create_attrs)
      name = name.strip
      existing = scope.find_by(slug: Slugifyer.slugify(name))
      return PrimaryActivity.create!(name:, **create_attrs) unless existing

      existing.update!(name:) unless existing.name == name
      existing
    end

    conceal :names_and_families, :update_or_create_for!, :upsert!
  end
end
