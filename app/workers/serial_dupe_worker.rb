class SerialDupeWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'stolen'
  sidekiq_options backtrace: true
    
  def perform(id)
    bike = Bike.unscoped.find(id)
    return true if bike.serial_number == 'absent'
    # matching_ids = BikeSearcher.new(serial: bike.serial_number).fuzzy_find_serial_ids
    matching_ids = Bike.where(serial_normalized: bike.serial_normalized).pluck(:id)
    if matching_ids.count > 1
      redis = Redis.new
      xids = redis.hget('duped_normalized', bike.serial_normalized)
      xids ||= ''
      matching_ids = (xids.split(',') + matching_ids).uniq
      redis.hset('duped_normalized', bike.serial_normalized, matching_ids.join(','))
    end
  end

end