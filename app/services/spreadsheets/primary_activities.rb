# frozen_string_literal: true

require "csv"

module Spreadsheets
  module PrimaryActivities
    extend Functionable

    EXPORT_COLUMNS = %i[flavor families priority short_name].freeze

    def to_csv(primary_activities = nil)
      primary_activities ||= PrimaryActivity.by_priority.includes(:primary_activity_family)

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
      # A flavor in several families exports once, with its first (highest priority) record's attributes
      flavor_records = {}
      # A family exports as a flavor-less row; import upserts the family and creates no flavor
      family_rows = []

      primary_activities.each do |primary_activity|
        if primary_activity.family?
          family_rows << [nil, primary_activity.name, primary_activity.priority, primary_activity.short_name]
          next
        end

        flavor_records[primary_activity.name] ||= primary_activity
        family_name = primary_activity.top_level? ? nil : primary_activity.family_name
        flavors_families[primary_activity.name] ||= family_name
        next if flavors_families[primary_activity.name] == family_name

        # If the name wasn't assigned in this block, add it
        flavors_families[primary_activity.name] += " & #{family_name}"
      end

      family_rows + flavors_families.map { |name, families| [name, families, flavor_records[name].priority, flavor_records[name].short_name] }
    end

    def update_or_create_for!(row)
      attributes = {priority: row[:priority].presence&.to_i, short_name: row[:short_name].presence}
      # A flavor row's attributes are the flavor's, not its families'
      family_attributes = row[:flavor].blank? ? attributes : {}
      family_ids = row[:families].presence&.split("&")&.map do |name|
        upsert!(PrimaryActivity.family, name, family_attributes, family: true).id
      end
      return if row[:flavor].blank?

      (family_ids || [nil]).each do |primary_activity_family_id|
        # Top-level flavors self-reference their id, so nil never matches them
        scope = primary_activity_family_id ? PrimaryActivity.where(primary_activity_family_id:) : PrimaryActivity.flavor.top_level
        upsert!(scope, row[:flavor], attributes, primary_activity_family_id:, family: false)
      end
    end

    # Match by slug or exact name (not friendly_find's substring search), correct the stored attributes, or create
    def upsert!(scope, name, attributes, **create_attrs)
      name = name.strip
      attributes = {name:, **attributes}.compact
      existing = scope.find_by(slug: Slugifyer.slugify(name)) ||
        scope.where("lower(name) = ?", name.downcase).first
      return PrimaryActivity.create!(**attributes, **create_attrs) unless existing

      existing.assign_attributes(attributes)
      existing.save! if existing.changed?
      existing
    rescue ActiveRecord::RecordInvalid => e
      raise "PrimaryActivity #{name.inspect} — #{e.message}"
    end

    conceal :names_and_families, :update_or_create_for!, :upsert!
  end
end
