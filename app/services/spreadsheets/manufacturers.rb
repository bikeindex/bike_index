# frozen_string_literal: true

require "csv"

class Spreadsheets::Manufacturers
  EXPORT_COLUMNS = %i[name alternate_name website makes_frames ebike_only open_year close_year
    logo_url].freeze

  class << self
    def to_csv(manufacturers = nil)
      manufacturers ||= Manufacturer.except_other

      CSV.generate do |csv|
        csv << EXPORT_COLUMNS
        manufacturers.each { csv << row_for(_1) }
      end
    end

    def import(csv)
      CSV.foreach(csv, headers: true, header_converters: :symbol) do |row|
        update_or_create_for!(row)
      end
    end

    private

    def update_or_create_for!(row)
      manufacturer = Manufacturer.friendly_find(row[:name])
      manufacturer ||= Manufacturer.friendly_find(row[:alternate_name]) if row[:alternate_name].present?
      manufacturer ||= Manufacturer.new
      manufacturer.name = if row[:alternate_name].present?
        "#{row[:name]} (#{row[:alternate_name]})"
      else
        row[:name]
      end
      manufacturer.frame_maker = InputNormalizer.boolean(row[:makes_frames])
      manufacturer.motorized_only = InputNormalizer.boolean(row[:ebike_only])
      manufacturer.open_year = row[:open_year]
      manufacturer.close_year = row[:close_year]
      manufacturer.website = row[:website]
      # Ignoring logo for now
      manufacturer.save! if manufacturer.changed?
    end

    def row_for(manufacturer)
      export_column_methods.map do |meth|
        next if meth.blank?

        result = manufacturer.send(meth)
        if meth == :logo_url && result == ManufacturerLogoUploader::FALLBACK_IMAGE
          nil
        else
          result
        end
      end
    end

    def export_column_methods
      EXPORT_COLUMNS.map do |key|
        case key
        when :name then :short_name
        when :alternate_name then :secondary_name
        when :ebike_only then :motorized_only
        when :makes_frames then :frame_maker
        when :logo_url then :logo_url
        else
          key
        end
      end
    end
  end
end
