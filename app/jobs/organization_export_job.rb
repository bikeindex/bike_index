class OrganizationExportJob < ApplicationJob
  REG_FIELD_HEADERS = %w[phone extra_registration_number organization_affiliation student_id].freeze
  ADDRESS_KEYS = {"address" => "street", "address_2" => "street_2", "city" => "city", "state" => "state", "zipcode" => "zipcode"}.freeze

  sidekiq_options retry: false, queue: "med_priority"

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
      @export.rows = each_row { |row| sheet.add_row(row) }
    end
    return if @export_ebraked

    axlsx_package.serialize(file.path)
    @export.tmp_file.close
    true
  end

  def write_csv(file)
    require "csv"
    file.write(comma_wrapped_string(export_headers))
    each_row { |row| file.write(comma_wrapped_string(row)) }
    true
  end

  def each_row
    row_index = 0
    [@export.bikes_scoped, @export.incompletes_scoped].each do |scope|
      scope.find_each(batch_size: 100) do |bike_or_b_param|
        check_export_ebrake(row_index) # Run first thing in case it's already broken
        next unless export_bike?(bike_or_b_param)

        row_index += 1
        yield(bike_or_b_param.is_a?(Bike) ? bike_to_row(bike_or_b_param) : b_param_to_row(bike_or_b_param))
      end
    end
    row_index
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
    return false unless bike_or_b_param.is_a?(Bike)

    bike_or_b_param.avery_exportable?
  end

  def bike_to_row(bike)
    export_headers.map { |header| value_for_header(header, bike) }
  end

  def b_param_to_row(b_param)
    export_headers.map do |header|
      case header
      when "registered_at", "manufacturer", "owner_email", "vehicle_type", *ADDRESS_KEYS.keys
        value_for_header(header, b_param)
      when "phone", "organization_affiliation", "student_id" then b_param.send(header)
      when "status"
        Atoms::RegistrationStatusBadge::Component.status_humanized(b_param, override_status: Bike.status_humanized(b_param.status), skip_with_owner: true)
      when "model" then b_param.bike["frame_model"]
      when "serial" then b_param.bike["serial_number"]
      when "extra_registration_number" then b_param.bike["extra_registration_number"]
      when "color"
        %w[primary_frame_color_id secondary_frame_color_id tertiary_frame_color_id].map { |key|
          color_id = b_param.bike[key]
          color_id.present? ? Color.find(color_id).name : nil
        }.compact.join(", ")
      when "owner_name" then b_param.user_name
      when "bike_sticker" then b_param.bike_sticker_code
      when "partial_registration" then true
      end
    end
  end

  def export_headers
    return @export_headers if defined?(@export_headers)

    @export_headers = @export.headers
    if @export_headers.include?("address")
      # Remove address and re-add, because we want to keep them in line
      @export_headers = (@export_headers - ["address"]) + ADDRESS_KEYS.keys
    end
    # If there are partial registrations, always include partial_registration
    if @export.partial_registrations.present? && @export_headers.exclude?("partial_registration")
      @export_headers += ["partial_registration"]
    end
    if @export.assign_bike_codes?
      @export_headers << "assigned_sticker"
      @bike_stickers = []
      @bike_sticker = BikeSticker.lookup(@export.bike_code_start, organization_id: @export.organization_id)
    end
    @export.options = @export.options.merge(written_headers: @export_headers) # Write the actual headers so we have them
    @export_headers
  end

  # Each column's value as the registrations search table shows it
  def value_for_header(header, bike)
    return bike.registration_address[ADDRESS_KEYS[header]] if ADDRESS_KEYS.key?(header)
    if REG_FIELD_HEADERS.include?(header)
      return OrgServices::RegistrationFields.value(bike:, organization: @export.organization, reg_field: "reg_#{header}")
    end

    case header
    when "link" then bike.html_url
    when "thumbnail" then BikeServices::Displayer.thumb_image_url(bike)
    when "registered_at" then bike.created_at.utc
    when "updated_at" then bike.updated_by_user_fallback.utc
    when "occurred_at" then bike.occurred_at&.utc
    when "status" then Atoms::RegistrationStatusBadge::Component.status_humanized(bike, skip_with_owner: true)
    when "manufacturer" then bike.mnfg_name
    when "model" then bike.frame_model
    when "color" then bike.frame_colors.join(", ")
    when "serial" then bike.serial_number
    when "vehicle_type" then bike.type_titleize
    when "propulsion_type" then bike.propulsion_titleize unless bike.propulsion_type == "foot-pedal"
    when "registration_method" then Ownership.creation_kind_humanized(bike.creation_kind)
    when "owner_email" then bike.owner_email
    when "owner_name" then bike.owner_name
    when "organization_notes" then organization_note_bodies[bike.id]
    when "bike_sticker" then bike.bike_stickers.map(&:pretty_code).join(" and ")
    when "assigned_sticker" then assign_bike_code_and_increment(bike)
    when "impound_id" then bike.current_impound_record&.display_id if bike.status_impounded?
    when "acknowledged_at"
      RegistrationSequenceAcknowledgment.find_for(bike:, organization: @export.organization)&.acknowledged_at&.utc if bike.motorized?
    when "avery_exportable" then bike.avery_exportable?
    end
  end

  # to_h can't collide: unique index on (bike_id, organization_id)
  def organization_note_bodies
    @organization_note_bodies ||= BikeOrganizationNote.where(organization_id: @export.organization_id)
      .pluck(:bike_id, :body).to_h
  end

  def assign_bike_code_and_increment(bike)
    return "" unless @bike_sticker.present?

    code = @bike_sticker.code
    pretty_code = @bike_sticker.pretty_code
    @bike_sticker.claim(user: @export.user,
      bike: bike,
      organization: @export.organization,
      export_id: @export.id,
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
