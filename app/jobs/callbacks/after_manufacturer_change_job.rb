# frozen_string_literal: true

class Callbacks::AfterManufacturerChangeJob < ApplicationJob
  sidekiq_options queue: "low_priority"

  def perform(manufacturer_id)
    manufacturer = Manufacturer.find(manufacturer_id)
    return unless manufacturer.present?

    Bike.unscoped.where("manufacturer_other ILIKE ?", manufacturer.short_name)
      .find_each { |bike| update_bike(bike, manufacturer_id) }
    return if manufacturer.secondary_name.blank?

    Bike.unscoped.where("manufacturer_other ILIKE ?", manufacturer.secondary_name)
      .find_each { |bike| update_bike(bike, manufacturer_id) }
  end

  def update_bike(bike, manufacturer_id)
    bike.update(manufacturer_id: manufacturer_id, manufacturer_other: nil)

    # Needs to happen after the manufacturer has been assigned to everything
    UpdateModelAuditJob.perform_in(5.minutes, bike.id)
  end
end
