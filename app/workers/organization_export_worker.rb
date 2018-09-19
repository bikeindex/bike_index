require 'csv'

class OrganizationExportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards" # Because it's low priority!
  sidekiq_options backtrace: true
  LINK_BASE = "#{ENV["BASE_URL"]}/bikes/".freeze

  attr_accessor :export # Only necessary for testing

  def perform(export_id)
    @export = Export.find(export_id)
    return true if @export.finished?
    return false unless create_csv(@bulk_import.open_file)
    @export.progress = "finished"
    @bulk_import.save
  end

  def create_csv(file)
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
    when "registered_at" then bike.created_at.utc
    when "manufacturer" then bike.mnfg_name
    when "model" then bike.frame_model
    when "color" then bike.frame_colors.join(', ')
    when "serial" then bike.serial_number
    when "is_stolen" then bike.stolen
    end
  end
end
