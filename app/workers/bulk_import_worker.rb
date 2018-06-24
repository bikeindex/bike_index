require 'csv'

class BulkImportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterward" # Because it's low priority!
  sidekiq_options backtrace: true

  attr_accessor :bulk_import

  def perform(bulk_import_id)
    @bulk_import = BulkImport.find(bulk_import_id)

    process_csv_file(@bulk_import.file)
  end

  def process_csv_file(file)
    CSV.new(file, headers: true, header_converters: :symbol) do |r|
      break if @bulk_import.file_import_errors.present?
      register_bike(r)
    end
  end

  def register_bike(row)
    validate_headers(r.keys) unless defined?(@valid_headers)
  end

  private

  def validate_headers(attrs)
    @valid_headers = (attrs & %i[manufacturer email serial]).count == 3
    # if @valid_headers
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
