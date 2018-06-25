require 'csv'

class BulkImportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterward" # Because it's low priority!
  sidekiq_options backtrace: true

  attr_accessor :bulk_import

  def perform(bulk_import_id)
    @bulk_import = BulkImport.find(bulk_import_id)
    return false unless process_csv(@bulk_import.file)
    @bulk_import.update_attributes(progress: "finished")
  end

  def process_csv(file)
    return false if @bulk_import.finished? # If url fails to load, this will catch
    CSV.new(file, headers: true, header_converters: [:downcase, :symbol]).each do |r|
      validate_headers(r.headers) unless @valid_headers # Check headers first, so we can break if they fail
      break false if @bulk_import.finished?
      register_bike(row_to_b_param_hash(r.to_h))
    end
  end

  def register_bike(b_param_hash)
    b_param = BParam.create(creator_id: @bulk_import.user_id,
                            params: b_param_hash,
                            origin: 'bulk_import_worker')
    BikeCreator.new(b_param).create_bike
  end

  def row_to_b_param_hash(row)
    {
      bike: {
        is_bulk: true,
        manufacturer_id: row[:manufacturer],
        owner_email: row[:email],
        color: row[:color],
        serial_number: row[:serial],
        year: row[:year],
        frame_model: row[:model],
        send_email: @bulk_import.send_email,
        creation_organization_id: @bulk_import.organization_id
      }
    }
  end

  private

  def validate_headers(attrs)
    @valid_headers = (attrs & %i[manufacturer email serial]).count == 3
    return true if @valid_headers
    @bulk_import.add_file_error("Invalid CSV Headers: #{attrs}")
  end

  def permitted_csv_attrs # Mayber there is a way to rename the headers, ignoring for now
    {
      manufacturer: :manufacturer_id,
      model: :frame_model,
      year: :frame_year,
      color: :color,
      email: :email,
      serial: :serial_number
    }
  end
end
