class MigrateUpdateByUserAtWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    bike.update_column :updated_by_user_at, bike.current_ownership&.claimed_at || bike.created_at
  end
end
