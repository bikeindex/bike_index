# frozen_string_literal: true

require "csv"

class Spreadsheets::Manufacturer
  EXPORT_COLUMNS = %i[name alternate_name website makes_frames ebike_only open_year close_year
    logo_url].freeze

  class << self
    def to_csv(manufacturers = nil)
      manufacturers ||= Manufacturer.all

      CSV.generate do |csv|
        csv << EXPORT_COLUMNS
        manufacturers.each { csv << row_for(_1) }
      end
    end

    private

    def row_for(manufacturer)
      export_column_methods.map do |meth|
        next if meth.blank?

        manufacturer.send(meth)
      end
    end

    def export_column_methods
      EXPORT_COLUMNS.map do |key|
        case key
        when :name then :simple_name
        when :ebike_only then :motorized_only
        when :makes_frames then :frame_maker
        when :logo_url then nil
        else
          key
        end
      end
    end
  end
end
