# frozen_string_literal: true

module Backfills
  # Manufacturer.friendly_find reads an all-digit slug as an id, so these were unreachable by slug
  class ManufacturerDigitSlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Manufacturer.where("slug ~ '^[0-9]+$' OR secondary_slug ~ '^[0-9]+$'").find_each(&:save)
    end
  end
end
