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
      register_bike(r.to_h)
    end
  end

  def register_bike(row)
    b_param = BParam.create(creator_id: @bulk_import.user_id,
                            params: row,
                            origin: 'bulk_importer')
    BikeCreator.new(b_param).create_bike
  end

  private

  def validate_headers(attrs)
    @valid_headers = (attrs & %i[manufacturer email serial]).count == 3
    return true if @valid_headers
    @bulk_import.add_file_error("Invalid CSV Headers: #{attrs}")
  end

  def permitted_csv_attrs
    {
      manufacturer: :manufacturer,
      model: :frame_model,
      year: :frame_year,
      color: :color,
      email: :email,
      serial: :serial_number
    }
  end
end
