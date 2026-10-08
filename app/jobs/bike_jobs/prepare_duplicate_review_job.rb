# frozen_string_literal: true

module BikeJobs
  class PrepareDuplicateReviewJob < ApplicationJob
    sidekiq_options retry: false

    def perform(database, token)
      return unless database == ActiveRecord::Base.connection_db_config.database

      cache = BikeServices::DuplicateReviewFinder.cache
      key = BikeServices::DuplicateReviewFinder.cache_key(database)
      preparation_key = BikeServices::DuplicateReviewFinder.preparation_key(database)
      return if cache.read(key) || cache.read(preparation_key) != token

      ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
        cache.write(key,
          {generated_at: Time.current, groups: BikeServices::DuplicateReviewFinder.groups}, expires_in: 1.hour)
      end
    ensure
      cache.delete(preparation_key) if cache && cache.read(preparation_key) == token
    end
  end
end
