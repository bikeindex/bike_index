class MigratePostalCodeWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"
  sidekiq_options retry: false

  def perform(code, country_id = nil)
    country_id ||= Bike.unscoped.where("zipcode ILIKE ?", code&.strip).where.not(country_id: nil).first&.country_id
    new_zipcode = Geocodeable.format_postal_code(code, country_id)

    Bike.unscoped.where(country_id: [country_id, nil])
      .where(zipcode: code)
      .update_all(zipcode: new_zipcode, country_id: country_id)
  end
end
