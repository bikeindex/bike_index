# frozen_string_literal: true

require "csv"

module Spreadsheets
  module WheelSizes
    extend Functionable

    def import(csv)
      CSV.foreach(csv, headers: true, header_converters: :symbol) do |row|
        WheelSize.find_or_initialize_by(iso_bsd: row[:iso_bsd])
          .update!(row.to_h.slice(:name, :priority, :description))
      end
    end
  end
end
