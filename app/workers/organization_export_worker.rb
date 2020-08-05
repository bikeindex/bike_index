class OrganizationExportWorker < ApplicationWorker
  LINK_BASE = "#{ENV["BASE_URL"]}/bikes/".freeze

  sidekiq_options retry: false, queue: "low_priority"
  attr_accessor :export # Only necessary for testing

  def perform(export_id)
    @export = Export.find(export_id)
    return true if @export.finished_processing?
    @export.update_attribute :progress, "ongoing"
    write_spreadsheet(@export.file_format, @export.tmp_file)
    return if @export_ebraked
    @export.file = @export.tmp_file
    @export.progress = "finished"
    @export.options = @export.options.merge(bike_codes_assigned: @bike_stickers) if @export.assign_bike_codes?
    @export.assign_exported_bike_ids
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
      row_index = 0
      @export.bikes_scoped.find_each(batch_size: 100) do |bike|
        check_export_ebrake(row_index) # Run first thing in case it's already broken
        next unless export_bike?(bike)
        row_index += 1
        sheet.add_row(bike_to_row(bike))
      end
      @export.incompletes_scoped.find_each(batch_size: 100) do |b_param|
        check_export_ebrake(row_index) # Run first thing in case it's already broken
        next unless export_bike?(b_param)
        row_index += 1
        sheet.add_row(b_param_to_row(b_param))
      end
      @export.rows = row_index
    end
    return if @export_ebraked
    file.write(axlsx_package.to_stream.read)
    @export.tmp_file.close
    true
  end

  def write_csv(file)
    require "csv"
    file.write(comma_wrapped_string(export_headers))
    row_index = 0
    @export.bikes_scoped.find_each(batch_size: 100) do |bike|
      check_export_ebrake(row_index) # Run first thing in case it's already broken
      next unless export_bike?(bike)
      row_index += 1
      file.write(comma_wrapped_string(bike_to_row(bike)))
    end
    @export.incompletes_scoped.find_each(batch_size: 100) do |b_param|
      check_export_ebrake(row_index) # Run first thing in case it's already broken
      next unless export_bike?(b_param)
      row_index += 1
      file.write(comma_wrapped_string(b_param_to_row(b_param)))
    end
    true
  end

  def comma_wrapped_string(array)
    array.map { |val|
      '"' + val.to_s.tr("\\", "").gsub(/(\\)?"/, '\"') + '"'
    }.join(",") + "\n"
  end

  # If we have to load the bike record to check if it's a valid export, check conditions here
  # Currently avery_exports are the only ones that need to do this
  def export_bike?(bike_or_b_param)
    return false if @export_ebraked
    @avery_export ||= @export.avery_export?
    return true unless @avery_export
    # The address must include a street for it to be valid
    Export.avery_export_bike?(bike_or_b_param)
  end

  def bike_to_row(bike)
    export_headers.map { |header| value_for_header(header, bike) }
  end

  def b_param_to_row(b_param)
    export_headers.map do |header|
      case header
      when "registered_at" then b_param.created_at.utc
      when "manufacturer" then b_param.manufacturer&.name
      when "color"
        %w[primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id].map { |key|
          color_id = b_param.bike[key]
          color_id.present? ? Color.find(color_id).name : nil
        }.compact.join(", ")
      when "owner_email" then b_param.owner_email
      when "partial_registration" then true
      end
    end
  end

  def export_headers
    return @export_headers if defined?(@export_headers)
    @export_headers = @export.headers
    if @export_headers.include?("address")
      # Remove address and readd, because we want to keep them in line
      @export_headers = (@export_headers - ["address"]) + %w[address city state zipcode]
    end
    @export_headers += ["partial_registration"] if @export.partial_registrations.present?
    if @export.assign_bike_codes?
      @export_headers << "assigned_sticker"
      @bike_stickers = []
      @bike_sticker = BikeSticker.lookup(@export.bike_code_start, organization_id: @export.organization_id)
    end
    @export.options = @export.options.merge(written_headers: @export_headers) # Write the actual headers so we have them
    @export_headers
  end

  MATCHING_KEYS = %w[owner_email owner_name year phone extra_registration_number organization_affiliation].freeze

  def value_for_header(header, bike)
    return bike.send(header) if MATCHING_KEYS.include?(header)
    case header
    when "link" then LINK_BASE + bike.id.to_s
    when "registration_method" then bike.creation_description
    when "thumbnail" then bike.thumb_path
    when "registered_at" then bike.created_at.utc
    when "manufacturer" then bike.mnfg_name
    when "model" then bike.frame_model
    when "color" then bike.frame_colors.join(", ")
    when "serial" then bike.serial_number
    when "is_stolen" then bike.stolen ? "true" : nil
    when "address" then bike.registration_address["street"] # These are the expanded values for bike registration address
    when "city" then bike.registration_address["city"]
    when "state" then bike.registration_address["state"]
    when "zipcode" then bike.registration_address["zipcode"]
    when "sticker" then bike.bike_stickers.map(&:pretty_code).join(" and ")
    when "assigned_sticker" then assign_bike_code_and_increment(bike)
    end
  end

  def assign_bike_code_and_increment(bike)
    return "" unless @bike_sticker.present?
    code = @bike_sticker.code
    pretty_code = @bike_sticker.pretty_code
    @bike_sticker.claim(user: @export.user,
                        bike: bike,
                        organization: @export.organization,
                        creator_kind: "creator_export")
    @bike_stickers << code
    @bike_sticker = @bike_sticker.next_unclaimed_code
    pretty_code
  end

  # This is difficult to test in an automated fashion, it's been tested by running it - so be careful about modifying
  def check_export_ebrake(row)
    return true if @export_ebraked # If it's already braked, don't check again
    # only check every so often, so we can halt processing via an external trip switch
    return true unless (row % 50).zero?
    reloaded_export = Export.where(id: @export.id).first
    # Specifically - if this export has been deleted, errored or somehow finished, halt processing
    return true unless reloaded_export.blank? || reloaded_export.finished_processing?
    @export_ebraked = true
    # And because this might have processed some bike_stickers after the export was deleted, remove them here
    return true unless @export.assign_bike_codes?
    @export.options = @export.options.merge(bike_codes_assigned: @bike_stickers)
    @export.remove_bike_stickers
  end
end
