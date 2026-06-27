# frozen_string_literal: true

require "csv"

module Spreadsheets
  module Components
    extend Functionable

    EXPORT_COLUMNS = %i[name secondary_name has_multiple_locations group].freeze

    def to_csv(ctypes = nil)
      ctypes ||= Ctype.includes(:cgroup).order(:name)

      CSV.generate do |csv|
        csv << EXPORT_COLUMNS
        ctypes.each { csv << row_for(it) }
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

    def update_or_create_for!(row)
      ctype = Ctype.friendly_find(row[:name]) || Ctype.new(name: row[:name])
      ctype.cgroup = find_or_create_cgroup(row[:group])
      ctype.secondary_name = row[:secondary_name]
      ctype.has_multiple = Binxtils::InputNormalizer.boolean(row[:has_multiple_locations])
      ctype.save! if ctype.changed?
    end

    def find_or_create_cgroup(name)
      name = name.presence || Cgroup.additional_parts.name
      Cgroup.friendly_find(name) || Cgroup.create!(name:)
    end

    def row_for(ctype)
      [ctype.name, ctype.secondary_name, ctype.has_multiple, ctype.cgroup&.name]
    end

    conceal :update_or_create_for!, :find_or_create_cgroup, :row_for
  end
end
