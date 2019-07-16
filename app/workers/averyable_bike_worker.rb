# Useful because of looking at PSU errors. Checkout https://github.com/bikeindex/bike_index/pull/1042

class AveryableBikeWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority"
  sidekiq_options backtrace: true

  def perform(filename, bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    return true if Export.avery_export_bike?(bike)
    File.open(filename, "a+") { |f| f << "\n#{bike.id}" }
  end
end
