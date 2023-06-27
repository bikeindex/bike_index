class MigrateBlankExtraRegistrationNumberWorker < ApplicationWorker
  sidekiq_options retry: false, queue: "low_priority"

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    return if bike.extra_registration_number.blank?
    if bike.extra_registration_number.match?(/(serial.)?#{bike.serial_number}/i)
      bike.update_column(extra_registration_number: nil)
    end
  end
end
