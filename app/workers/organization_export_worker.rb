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
    write_spreadsheet(@export.file_format, @export.tmp_file)
    @export.file = @export.tmp_file
    @export.progress = "finished"
    @export.save
    @export.tmp_file.unlink # Remove it and unlink
    @export
  end

  def write_spreadsheet(file_format, file)
    if file_format == "csv"
      # With CSV's we do a little lower level handling of file I/O (because we can, to save memory)
      # Deal with that in here
      write_csv(file)
      @export.tmp_file.close # Because buffered output, closing instead of rewinding
      @export.update_attribute :rows, @export.tmp_file_rows
    else # It's an excel file!
      write_excel(file)
    end
  end

  def write_excel(file)
    axlsx_package = Axlsx::Package.new
    axlsx_package.workbook.add_worksheet(name: "Basic Worksheet") do |sheet|
      sheet.add_row(export_headers)
      rows = 0
      @export.bikes_scoped.find_each(batch_size: 100) do |bike|
        next unless export_bike?(bike)
        rows += 1
        sheet.add_row(bike_to_row(bike))
      end
      @export.rows = rows
    end
    file.write(axlsx_package.to_stream.read)
    @export.tmp_file.close
    true
  end

  def write_csv(file)
    require "csv"
    file.write(comma_wrapped_string(export_headers))
    @export.bikes_scoped.find_each(batch_size: 100) do |bike|
      next unless export_bike?(bike)
      file.write(comma_wrapped_string(bike_to_row(bike)))
    end
    true
  end

  def comma_wrapped_string(array)
    array.map do |val|
      '"' + val.to_s.tr("\\", "").gsub(/(\\)?\"/, '\"') + '"'
    end.join(",") + "\n"
  end

  # If we have to load the bike record to check if it's a valid export, check conditions here
  # Currently avery_exports are the only ones that need to do this
  def export_bike?(bike)
    @avery_export ||= @export.avery_export?
    return true unless @avery_export
    # Avery export includes owner_name_or_email - but actually requires user_name - TODO: make it just user_name & update avery to accept user_name
    bike.registration_address.present? && bike.user_name.present?
  end

  def bike_to_row(bike)
    export_headers.map { |header| value_for_header(header, bike) }
  end

  def export_headers
    return @export_headers if defined?(@export_headers)
    @export_headers = @export.headers
    if @export_headers.include?("registration_address")
      @export_headers = @export_headers.reject { |v| v == "registration_address" } + %w[address city state zipcode]
    end
    if @export.assign_bike_codes?
      @export_headers << "sticker"
      @bike_code = BikeCode.lookup(@export.options["bike_code_start"], organization_id: @export.organization_id)
    end
    @export_headers
  end

  def value_for_header(header, bike)
    case header
    when "link" then LINK_BASE + bike.id.to_s
    when "owner_email" then bike.owner_email
    when "owner_name" then bike.user_name
    when "owner_name_or_email" then bike.user_name_or_email
    when "registration_method" then bike.creation_description
    when "thumbnail" then bike.thumb_path
    when "registered_at" then bike.created_at.utc
    when "manufacturer" then bike.mnfg_name
    when "model" then bike.frame_model
    when "year" then bike.year
    when "color" then bike.frame_colors.join(', ')
    when "serial" then bike.serial_number
    when "additional_registration_number" then bike.additional_registration
    when "phone" then bike.phone
    when "is_stolen" then bike.stolen ? "true" : nil
    when "address" then bike.registration_address["address"] # These are the expanded values for bike registration address
    when "city" then bike.registration_address["city"]
    when "state" then bike.registration_address["state"]
    when "zipcode" then bike.registration_address["zipcode"]
    when "sticker" then
      code = @bike_code.code
      @bike_code = @bike_code.next_code
      code
    end
  end
end
