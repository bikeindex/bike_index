# frozen_string_literal: true

# Backfill b_param parking_notification params to rename legacy attributes:
#   zipcode -> postal_code
#   state_id -> region_record_id
class Backfills::BParamParkingNotificationAttrsJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: false

  LEGACY_RENAMES = {"zipcode" => "postal_code", "state_id" => "region_record_id"}.freeze

  class << self
    def enqueue_all
      scope.find_each { |b_param| perform_async(b_param.id) }
    end

    def scope
      BParam.where("params -> 'parking_notification' ? 'zipcode' OR params -> 'parking_notification' ? 'state_id'")
    end
  end

  def perform(id)
    b_param = BParam.find(id)
    parking_attrs = b_param.params["parking_notification"]
    return if parking_attrs.blank?

    updated = false
    LEGACY_RENAMES.each do |old_key, new_key|
      if parking_attrs.key?(old_key)
        parking_attrs[new_key] = parking_attrs.delete(old_key)
        updated = true
      end
    end

    b_param.update_column(:params, b_param.params) if updated
  end
end
