class BulkImportWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterward' # Because it's low priority!
  sidekiq_options backtrace: true

  attr_accessor :organization, :bulk_import

  def perform(file_url, organization_id, user_id = nil)
    existing = BulkImport.where(file_url: file_url, organization_id: organization_id).first
    return existing if existing.present?
    @organization = Organization.find organization_id
    @bulk_import = BulkImport.create(file_url: file_url, organization_id: organization_id, user_id: user_id)
    process_import(file_url)
  end

  def csv_from_url(file_url)
    CSV.foreach(file_url, headers: true, header_converters: :symbol) { |r| register_bike(r) }
  end

  def register_bike(row)
    validate_headers(r.keys) unless @valid_headers
  end

  private

  def validate_headers(attrs)
    @valid_headers = (attrs & %i[manufacturer email serial]).count == 3
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
