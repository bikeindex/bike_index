# frozen_string_literal: true

class Backfills::AddressRecordsForOwnershipsJob < ApplicationJob
  include Sidekiq::IterableJob

  sidekiq_options queue: "low_priority", retry: false

  class << self
    def iterable_scope
      Ownership.with_reg_info_location.where(address_record_id: nil)
    end

    def build_or_create_for(ownership, country_id: nil)
      return ownership.address_record if ownership.address_record.present?

      # Let the internal ownership calculated attribute handle it
      ownership.update(updated_at: Time.current)
    end
  end

  def build_enumerator(cursor:)
    return if skip_job?

    active_record_records_enumerator(self.class.iterable_scope, cursor:)
  end

  def each_iteration(ownership)
    self.class.build_or_create_for(ownership)
  end
end
