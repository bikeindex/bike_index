# frozen_string_literal: true

require "csv"

class Spreadsheets::PrimaryActivities
  EXPORT_COLUMNS = %i[flavor families].freeze

  class << self
    def to_csv(primary_activities = nil)
      primary_activities ||= PrimaryActivity.by_priority

      CSV.generate do |csv|
        csv << EXPORT_COLUMNS
        names_and_families(primary_activities).each { csv << _1 }
      end
    end

    def import(csv)
      CSV.foreach(csv, headers: true, header_converters: :symbol) do |row|
        update_or_create_for!(row)
      end
    end

    private

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
      family_ids = if row[:families].present?
        # Find or create the matching families
        row[:families].split("&").map do |name|
          PrimaryActivity.family.friendly_find(name)&.id ||
            PrimaryActivity.create!(name:, family: true).id
        end
      end
      return if row[:flavor].blank?

      (family_ids || [nil]).each do |primary_activity_family_id|
        PrimaryActivity.where(primary_activity_family_id:).friendly_find(row[:flavor]) ||
          PrimaryActivity.create(name: row[:flavor], primary_activity_family_id:, family: false)
      end
    end
  end
end
