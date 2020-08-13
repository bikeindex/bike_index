# Useful because of looking at PSU errors.
# Checkout https://github.com/bikeindex/bike_index/pull/1042

class AveryableBikeWorker < ApplicationWorker
  def perform(filename, bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    return true if bike.avery_exportable?
    File.open(filename, "a+") { |f| f << "\n#{bike.id}" }
  end
end
