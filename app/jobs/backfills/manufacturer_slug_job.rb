# frozen_string_literal: true

module Backfills
  class ManufacturerSlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Manufacturer.unscoped.find_each(&:save!)
    end
  end
end
