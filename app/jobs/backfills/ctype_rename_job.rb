# frozen_string_literal: true

module Backfills
  # Shorter names, so the slugs derived from them match. Slugs are set on create, so they're unchanged
  class CtypeRenameJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    RENAMES = {
      "Cog/Cassette/Freewheel" => {name: "Cassette", secondary_name: "Cog/Freewheel"},
      "Bashguard/Chain Guide" => {name: "Chain Guide", secondary_name: "Bashguard"},
      "E-vehicle Display/Remote" => {name: "E-vehicle Remote", secondary_name: "E-vehicle Display, Electric Bike Computer"}
    }.freeze

    def perform
      RENAMES.each { |name, attributes| Ctype.find_by(name:)&.update!(attributes) }
    end
  end
end
