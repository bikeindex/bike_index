# frozen_string_literal: true

module CallbackJobs
  class AfterManufacturerChangeJob < ApplicationJob
    sidekiq_options queue: "low_priority"

    def perform(manufacturer_id)
      manufacturer = Manufacturer.find(manufacturer_id)
      slugs = [manufacturer.slug, manufacturer.secondary_slug].compact_blank

      matching_others(Bike, slugs).find_each { |bike| update_bike(bike, manufacturer_id) }
      matching_others(Component, slugs).find_each { it.update(manufacturer_id:, manufacturer_other: nil) }

      # Bump manufacturer in case the priority changed
      # callback job is only run if manufacturer name changed
      manufacturer.update(updated_at: Time.current)
    end

    private

    # Slug match, so "BMC-Switzerland" finds "BMC (BMC Switzerland)"
    def matching_others(klass, slugs)
      others = klass.unscoped.where(manufacturer_id: Manufacturer.other.id)
      names = others.distinct.pluck(:manufacturer_other).select { slugs.include?(Slugifyer.manufacturer(it)) }
      others.where(manufacturer_other: names)
    end

    def update_bike(bike, manufacturer_id)
      bike.update(manufacturer_id:, manufacturer_other: nil)

      # Needs to happen after the manufacturer has been assigned to everything
      UpdateModelAuditJob.perform_in(5.minutes, bike.model_audit_id) if bike.model_audit_id.present?
    end
  end
end
