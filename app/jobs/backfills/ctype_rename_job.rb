# frozen_string_literal: true

module Backfills
  # Slugs are set on create, so a renamed ctype keeps its old one
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
