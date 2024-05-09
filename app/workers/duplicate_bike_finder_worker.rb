class DuplicateBikeFinderWorker < ApplicationWorker
  sidekiq_options retry: false, queue: "droppable"

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    return true if bike.blank?

    should_delete = bike.blank? || bike.deleted_at.present? || bike.example ||
      bike.likely_spam

    serial_segments = NormalizedSerialSegment.where(bike_id: bike_id)

    serial_segments.considered_for_duplicate.each do |serial_segment|
      existing_duplicate = DuplicateBikeGroup.matching_segment(serial_segment.segment)
      if should_delete
        remove_orphaned_duplicate(existing_duplicate, serial_segment) if existing_duplicate.present?
      elsif existing_duplicate.present?
        serial_segment.update_attribute :duplicate_bike_group_id, existing_duplicate.id
        existing_duplicate.update_attribute :added_bike_at, Time.current
      else
        duplicate_segments = NormalizedSerialSegment.where(segment: serial_segment.segment)
        if duplicate_segments.count > 1
          duplicate_group = DuplicateBikeGroup.create
          duplicate_segments.each do |duplicate_segment|
            next if duplicate_segment.duplicate_bike_group_id.present?
            duplicate_segment.update_attribute :duplicate_bike_group_id, duplicate_group.id
          end
          duplicate_group.destroy if duplicate_group.normalized_serial_segments.empty?
        end
      end
    end

    serial_segments.destroy_all if should_delete
  end

  def remove_orphaned_duplicate(duplicate_bike_group, normalized_serial_segment)
    other_segments = duplicate_bike_group.normalized_serial_segments.where.not(id: normalized_serial_segment.id)
    not_orphaned = false
    # Check the other segments to verify that *they* aren't orphans
    other_segments.each do |other_segment|
      bike = Bike.unscoped.find_by_id(other_segment.bike_id)
      if bike.present? && bike.deleted_at.blank? && !bike.example && !bike.likely_spam
        not_orphaned = true
      else
        other_segment.destroy
      end
    end
    duplicate_bike_group.destroy if not_orphaned
  end
end
