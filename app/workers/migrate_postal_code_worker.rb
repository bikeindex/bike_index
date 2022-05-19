class MigratePostalCodeWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"
  sidekiq_options retry: false

  def perform(code, country_id)
    new_zipcode = Geocodeable.format_postal_code(code, country_id)
    Bike.where(zipcode: code, country_id: country_id)
      .update_all(zipcode: new_zipcode)
  end
end
