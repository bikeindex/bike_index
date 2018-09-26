class OrganizationExportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards" # Because it's low priority!
  sidekiq_options backtrace: true
  LINK_BASE = "#{ENV['BASE_URL']}/bikes/".freeze

  attr_accessor :export # Only necessary for testing

  def perform(export_id)
    @export = Export.find(export_id)
    return true if @export.finished?
    @export.update_attribute :progress, "ongoing"
    write_csv(@export.tmp_file)
    @export.tmp_file.close # Because buffered output, closing instead of rewinding
    @export.update_attribute :rows, @export.tmp_file_rows
    @export.file = @export.tmp_file
    @export.progress = "finished"
    @export.save
    @export.tmp_file.unlink # Remove it and unlink
    @export
  end

  def write_csv(file)
    require "csv"
    file.write(comma_wrapped_string(export_headers))
    @export.bikes_scoped.find_each(batch_size: 100) do |bike|
      file.write(comma_wrapped_string(bike_to_row(bike)))
    end
    true
  end

  def comma_wrapped_string(array)
    array.map do |val|
      '"' + val.to_s.tr("\\", "").gsub(/(\\)?\"/, '\"') + '"'
    end.join(",") + "\n"
  end

  def bike_to_row(bike)
    export_headers.map { |header| value_for_header(header, bike) }
  end

  def export_headers
    @export_headers ||= @export.headers
  end

  def value_for_header(header, bike)
    case header
    when "link" then LINK_BASE + bike.id.to_s
    when "owner_email" then bike.owner_email
    when "owner_name" then bike.owner_name
    when "registration_method" then bike.creation_description
    when "thumbnail" then bike.thumb_path
    when "registered_at" then bike.created_at.utc
    when "manufacturer" then bike.mnfg_name
    when "model" then bike.frame_model
    when "year" then bike.year
    when "color" then bike.frame_colors.join(', ')
    when "serial" then bike.serial_number
    when "is_stolen" then bike.stolen ? "true" : nil
    end
  end
end
