class DuplicateBikeFinderWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, :retry => false

  def perform(bike_id)
    serial_segments = Bike.find(bike_id).normalized_serial_segments

    serial_segments.each do |serial_segment|
      existing_duplicate = DuplicateBikeGroup.includes(:normalized_serial_segments).
        where(normalized_serial_segments: { segment: serial_segment.segment }).first
      if existing_duplicate.present?
        serial_segment.update_attribute :duplicate_bike_group_id, existing_duplicate.id 
        existing_duplicate.update_attribute :added_bike_at, Time.now
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


  end

end