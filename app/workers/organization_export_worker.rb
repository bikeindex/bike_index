require 'csv'

class OrganizationExportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards" # Because it's low priority!
  sidekiq_options backtrace: true

  attr_accessor :export # Only necessary for testing

  def perform(export_id)
    @export = Export.find(export_id)
    return true if @export.finished?
    return false unless create_csv(@bulk_import.open_file)
    @export.progress = "finished"
    return @bulk_import.save unless @line_errors.any?
    # Using update_attribute here to avoid validation checks that sometimes block updating postgres json in rails
    export.update_attribute :export_errors, (export.import_errors || {}).merge("line" => @line_errors.compact)
  end

  def create_csv(file)
  end

  def bike_to_row(bike)
    export_headers.map { |h| bike.send(h) }
  end

  def export_headers
    @export_headers ||= headers_to_bike_attrs.as_json.slice(*@export.headers).values
  end

  def headers_to_bike_attrs
    {
      registered_at: "created_at.utc",
      manufacturer: :mnfg_name,
      model: :frame_model,
      color: "frame_colors.join(', ')",
      serial: :serial_number,
      is_stolen: :is_stolen,
    }
  end
end
