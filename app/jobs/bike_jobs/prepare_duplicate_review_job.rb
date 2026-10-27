# frozen_string_literal: true

module BikeJobs
  class PrepareDuplicateReviewJob < ApplicationJob
    sidekiq_options retry: false

    def perform(claim)
      BikeDuplicatesServices::Finder.store_group_snapshot(claim:)
    end
  end
end
