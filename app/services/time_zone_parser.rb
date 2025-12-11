# frozen_string_literal: true

module TimeZoneParser
  class << self
    delegate :parse, :parse_from_time_string, :parse_from_time_and_offset, :full_name, to: "BinxUtils::TimeZoneParser"
  end
end
