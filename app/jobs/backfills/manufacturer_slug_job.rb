# frozen_string_literal: true

module Backfills
  class ManufacturerSlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    # A lookup is slugified to dashes, so an underscored previous slug can't match
    def perform
      Manufacturer.unscoped.find_each { it.update!(previous_slugs: it.previous_slugs.map { |slug| slug.tr("_", "-") }) }
    end
  end
end
