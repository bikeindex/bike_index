class MigrateBlankExtraRegistrationNumberWorker < ApplicationWorker
  sidekiq_options retry: false, queue: "low_priority"

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    updated_extra_registration_number = ParamsNormalizer.strip_or_nil_if_blank(bike.extra_registration_number)
    return if bike.extra_registration_number == updated_extra_registration_number
    bike.update_column(:extra_registration_number, updated_extra_registration_number)
  end
end
