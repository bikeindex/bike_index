require 'csv'

class BulkImportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards" # Because it's low priority!
  sidekiq_options backtrace: true, retry: false

  attr_accessor :bulk_import, :line_errors # Only necessary for testing

  def perform(bulk_import_id)
    @bulk_import = BulkImport.find(bulk_import_id)
    process_csv(@bulk_import.open_file)
    return false if @bulk_import.import_errors?

    @bulk_import.progress = "finished"
    return @bulk_import.save unless @line_errors.any?

    # Using update_attribute here to avoid validation checks that sometimes block updating postgres json in rails
    @bulk_import.update_attribute :import_errors, (@bulk_import.import_errors || {}).merge("line" => @line_errors.compact)
  end

  def process_csv(open_file)
    @line_errors = @bulk_import.line_import_errors || [] # We always need line_import_errors
    return false if @bulk_import.finished? # If url fails to load, this will catch

    # Grab the first line of the csv (which is the header line) and transform it
    headers = convert_headers(open_file.readline)
    # Stream process the rest of the csv
    row_index = 1 # We've already remove the first line, so it doesn't count. and we want lines to start at 1, not 0
    csv = CSV.new(open_file, headers: headers)
    while (row = csv.shift)
      row_index += 1 # row_index is current line number
      @bulk_import.reload if (row_index % 50).zero? # reload import every so often to check if import is finished (external trip switch)
      break false if @bulk_import.finished? # Means there was an error or we marked finished separately, so noop

      bike = register_bike(row_to_b_param_hash(row.to_h))
      next if bike.id.present?

      @line_errors << [row_index, bike.cleaned_error_messages]
    end
  rescue => e
    @bulk_import.add_file_error(e)
    raise e
  end

  def register_bike(b_param_hash)
    b_param = BParam.create(creator_id: creator_id,
                            params: b_param_hash,
                            origin: "bulk_import_worker")
    BikeCreator.new(b_param).create_bike
  end

  def row_to_b_param_hash(row_with_whitespaces)
    # remove whitespace from the values in the row
    row = row_with_whitespaces.map do |k, v|
      next [k, v] unless v.is_a?(String)

      [k, v.blank? ? nil : v.strip]
    end.to_h

    {
      bulk_import_id: @bulk_import.id,
      bike: {
        is_bulk: true,
        # Set default manufacturer, since sometimes manufacturer is blank
        manufacturer_id: row[:manufacturer].present? ? row[:manufacturer] : "Unknown",
        owner_email: row[:owner_email],
        # Set a default color of black, since sometimes there aren't colors in imports
        color: row[:color].present? ? row[:color] : "Black",
        serial_number: rescue_blank_serial(row[:serial_number]),
        year: row[:year],
        frame_model: row[:model],
        description: row[:description],
        frame_size: row[:frame_size],
        phone: row[:phone],
        address: row[:address],
        user_name: row[:owner_name],
        additional_registration: row[:secondary_serial],
        send_email: @bulk_import.send_email,
        creation_organization_id: @bulk_import.organization_id
      },
      # Photo need to be an array - only include if photo has a value
      photos: row[:photo].present? ? [row[:photo]] : nil
    }
  end

  def rescue_blank_serial(serial)
    return "absent" unless serial.present?

    serial.strip!
    if ["n.?a", "none", "unkn?own"].any? { |m| serial.match(/\A#{m}\z/i).present? }
      "absent"
    else
      serial
    end
  end

  def creator_id
    # We want to use the organization auto user id if it exists
    @creator_id ||= @bulk_import.creator.id
  end

  def convert_headers(str)
    headers = str.split(",").map { |h| h.gsub(/\"|\'/, "").strip.gsub(/\s/, "_").downcase.to_sym }
    header_name_map.each do |value, replacements|
      next if headers.include?(value)

      replacements.each do |v|
        next unless headers.index(v).present?

        headers[headers.index(v)] = value
        break # Because we've found the header we're replacing, stop iterating
      end
    end
    validate_headers(headers)
    headers
  end

  private

  def validate_headers(attrs)
    required_headers = %i[manufacturer owner_email serial_number]
    valid_headers = (attrs & required_headers).count == 3
    # Update progress here, since we're successfully processing the file now - and we update here if invalid headers
    return @bulk_import.update_attribute :progress, "ongoing" if valid_headers
    missing_headers = required_headers - (attrs & required_headers)
    @bulk_import.add_file_error("Invalid CSV Headers: #{attrs.join(", ")} - missing #{missing_headers.join(", ")}")
  end

  def header_name_map
    {
      manufacturer: %i[manufacturer_id brand vendor],
      model: %i[frame_model],
      year: %i[frame_year],
      serial_number: %i[serial],
      photo: %i[photo_url],
      owner_email: %i[email customer_email],
      frame_size: %i[size],
      description: %i[product_description]
    }
  end
end
