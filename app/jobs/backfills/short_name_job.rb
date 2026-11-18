# frozen_string_literal: true

module Backfills
  # The short names whose slugs (in bike_data's exports) can't be derived from the name
  class ShortNameJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    PRIMARY_ACTIVITY_SHORT_NAMES = {
      "Road Biking" => "Road",
      "Track Racing" => "Track",
      "Endurance / Sportive" => "Endurance"
    }.freeze

    CTYPE_SHORT_NAMES = {
      "Aero Bars/Extensions/Bar Ends" => "Aero Bars",
      "Cog/Cassette/Freewheel" => "Cassette",
      "Bashguard/Chain Guide" => "Chain Guide",
      "E-vehicle Display/Remote" => "E-vehicle Remote"
    }.freeze

    def perform
      PRIMARY_ACTIVITY_SHORT_NAMES.each { |name, short_name| PrimaryActivity.where(name:).each { it.update!(short_name:) } }
      CTYPE_SHORT_NAMES.each { |name, short_name| Ctype.where(name:).each { it.update!(short_name:) } }
    end
  end
end
