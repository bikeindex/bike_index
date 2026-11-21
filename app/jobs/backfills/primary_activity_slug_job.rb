# frozen_string_literal: true

module Backfills
  class PrimaryActivitySlugJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      PrimaryActivity.find_each(&:save!)
    end
  end
end
