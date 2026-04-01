# frozen_string_literal: true

# Backfill b_param parking_notification params to rename legacy attributes:
#   zipcode -> postal_code
#   state_id -> region_record_id
class Backfills::BParamParkingNotificationAttrsJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority"

  LEGACY_RENAMES = {"zipcode" => "postal_code", "state_id" => "region_record_id"}.freeze

  def self.iterable_scope
    BParam.where("params -> 'parking_notification' ? 'zipcode' OR params -> 'parking_notification' ? 'state_id'")
  end

  def build_enumerator(cursor:)
    return if skip_job?

    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(b_param)
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
