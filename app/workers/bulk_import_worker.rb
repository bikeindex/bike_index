require 'csv'

class BulkImportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards" # Because it's low priority!
  sidekiq_options backtrace: true

  attr_accessor :bulk_import, :line_errors # Only necessary for testing

  def perform(bulk_import_id)
    @bulk_import = BulkImport.find(bulk_import_id)
    return false unless process_csv(@bulk_import.open_file)
    @bulk_import.progress = "finished"
    return @bulk_import.save unless @line_errors.any?
    # Using update_attribute here to avoid validation checks that sometimes block updating postgres json in rails
    @bulk_import.update_attribute :import_errors, (@bulk_import.import_errors || {}).merge("line" => @line_errors.compact)
  end

  def process_csv(file)
    return false if @bulk_import.finished? # If url fails to load, this will catch
    @line_errors = @bulk_import.line_import_errors || []
    # This isn't stream processing. If memory becomes an issue,
    # figure out how to open a carrierwave file (rather than read) and switch CSV.parse -> CSV.new
    CSV.parse(file, headers: true, header_converters: %i[downcase symbol]).each_with_index do |row, index|
      validate_headers(row.headers) unless @valid_headers # Check headers first, so we can break if they fail
      break false if @bulk_import.finished?
      bike = register_bike(row_to_b_param_hash(row.to_h))
      next if bike.id.present?
      @line_errors << [index + 1, bike.cleaned_error_messages]
    end
  end

  def register_bike(b_param_hash)
    b_param = BParam.create(creator_id: creator_id,
                            params: b_param_hash,
                            origin: "bulk_import_worker")
    BikeCreator.new(b_param).create_bike
  end

  def row_to_b_param_hash(row)
    # Set a default color of black, since sometimes there aren't colors in imports
    color = row[:color].present? ? row[:color] : "Black"
    # Set default manufacture, since sometimes manufacture is blank
    manufacturer = row[:manufacturer].present? ? row[:manufacturer] : "Unknown"
    {
      bulk_import_id: @bulk_import.id,
      bike: {
        is_bulk: true,
        manufacturer_id: manufacturer,
        owner_email: row[:email],
        color: color,
        serial_number: rescue_blank_serial(row[:serial]),
        year: row[:year],
        frame_model: row[:model],
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

  private

  def validate_headers(attrs)
    @valid_headers = (attrs & %i[manufacturer email serial]).count == 3
    # Update the progress in here, since we're successfully processing the file right now
    return @bulk_import.update_attribute :progress, "ongoing" if @valid_headers
    @bulk_import.add_file_error("Invalid CSV Headers: #{attrs}")
  end

  def permitted_csv_attrs
    # Mayber there is a way to rename the headers, simple solution for now
    {
      manufacturer: :manufacturer_id,
      model: :frame_model,
      year: :frame_year,
      color: :color,
      email: :email,
      serial: :serial_number,
      photo_url: :photo
    }
  end
end
