# frozen_string_literal: true

module Backfills
  # SerialNormalizer stores placeholder serials ("NOT ASSIGNED") as unknown. Bikes registered before it did
  # keep the placeholder, which groups unrelated bikes as duplicates. Stores them as unknown and drops their
  # serial segments, releasing any duplicate group left with fewer than two bikes
  class UnknownSerialJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    # The comparison SerialNormalizer.looks_like_unknown? makes. Unindexed, which is fine once
    UNKNOWN_SQL = "lower(regexp_replace(serial_number, '[^a-zA-Z0-9]', '', 'g')) IN (?)"

    def perform
      bikes = Bike.unscoped.where(UNKNOWN_SQL, SerialNormalizer::UNKNOWN_STRINGS.to_a)
      group_ids = NormalizedSerialSegment.where(bike_id: bikes.select(:id)).duplicate_bike_group
        .distinct.pluck(:duplicate_bike_group_id)
      bikes.find_each do |bike|
        bike.update_columns(serial_number: "unknown", serial_normalized: nil, serial_normalized_no_space: nil,
          updated_at: Time.current)
        bike.create_normalized_serial_segments
      end
      DuplicateBikeGroup.where(id: group_ids).find_each do |group|
        next if group.normalized_serial_segments.count > 1

        group.normalized_serial_segments.update_all(duplicate_bike_group_id: nil)
        group.destroy
      end
    end
  end
end
