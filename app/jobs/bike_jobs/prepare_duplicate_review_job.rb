# frozen_string_literal: true

module BikeJobs
  class PrepareDuplicateReviewJob < ApplicationJob
    sidekiq_options retry: false

    def perform
      BikeDuplicatesServices::Finder.store_group_snapshot
    end
  end
end
