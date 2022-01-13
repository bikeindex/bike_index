class MigrateUpdateByUserAtWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"

  def bike_limit
    (ENV["MIGRATE_BIKE_LIMIT"] || 1000).to_i
  end

  def perform
    Bike.unscoped.where(updated_by_user_at: nil).limit(bike_limit).find_each do |bike|
      return if bike.updated_by_user_at.present?
      bike.update_column :updated_by_user_at, bike.current_ownership&.claimed_at || bike.created_at
    end
  end
end
