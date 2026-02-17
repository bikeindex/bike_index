# frozen_string_literal: true

class Backfills::OwnershipRegistrationInfoKeysJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority"

  # Maps old keys to new keys
  KEY_RENAMES = {
    "zipcode" => "postal_code",
    "state" => "region_string"
  }.freeze

  class << self
    def iterable_scope
      Ownership
        .where("(registration_info -> 'zipcode') IS NOT NULL")
        .or(Ownership.where("(registration_info -> 'state') IS NOT NULL"))
    end

    def updated_registration_info(registration_info)
      return registration_info if registration_info.blank?

      updated_info = registration_info.dup
      KEY_RENAMES.each do |old_key, new_key|
        next unless updated_info.key?(old_key)

        old_value = updated_info.delete(old_key)
        updated_info[new_key] ||= old_value
      end
      updated_info
    end
  end

  def build_enumerator(cursor:)
    return if skip_job?

    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(ownership)
    updated_info = self.class.updated_registration_info(ownership.registration_info)
    ownership.update_column(:registration_info, updated_info)
  end
end
