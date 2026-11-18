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
      families, flavors = primary_activities.partition(&:family?)
      # A family exports as a flavor-less row; import upserts the family and creates no flavor
      family_rows = families.map { [nil, it.name, it.priority, it.short_name] }
      # A flavor in several families exports once, with its first (highest priority) record's attributes
      family_rows + flavors.group_by(&:name).map do |name, records|
        family_names = records.reject(&:top_level?).map(&:family_name).join(" & ").presence
        [name, family_names, records.first.priority, records.first.short_name]
      end
    end

    def update_or_create_for!(row)
      priority = row[:priority].presence&.to_i
      # A flavor row's priority is the flavor's, not its families'
      family_ids = row[:families].presence&.split("&")&.map do |name|
        upsert!(PrimaryActivity.family, name, priority: (priority if row[:flavor].blank?), family: true).id
      end
      return if row[:flavor].blank?

      (family_ids || [nil]).each do |primary_activity_family_id|
        # Top-level flavors self-reference their id, so nil never matches them
        scope = primary_activity_family_id ? PrimaryActivity.where(primary_activity_family_id:) : PrimaryActivity.flavor.top_level
        upsert!(scope, row[:flavor], priority:, primary_activity_family_id:, family: false)
      end
    end

    # Slug or exact name, not friendly_find's substring search
    def upsert!(scope, name, priority:, **create_attrs)
      name = name.strip
      existing = scope.find_by(slug: Slugifyer.slugify(name)) ||
        scope.where("lower(name) = ?", name.downcase).first
      return PrimaryActivity.create!(name:, priority:, **create_attrs) unless existing

      existing.assign_attributes({name:, priority:}.compact)
      existing.save! if existing.changed?
      existing
    rescue ActiveRecord::RecordInvalid => e
      raise "PrimaryActivity #{name.inspect} — #{e.message}"
    end

    conceal :names_and_families, :update_or_create_for!, :upsert!
  end
end
