class GetManufacturerLogoWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, :retry => false
    
  def perform(id)
    manufacturer = Manufacturer.find(id)
    return true if manufacturer.website.blank? || manufacturer.logo.present?

    clearbit_url = "http://logo.clearbit.com/#{manufacturer.website.gsub(/\Ahttps?:\/\//i,'')}?size=400"

    status_response = Net::HTTP.get_response(URI(clearbit_url))
    return true unless status_response.kind_of? Net::HTTPSuccess

    manufacturer.remote_logo_url = clearbit_url
    manufacturer.logo_source = 'Clearbit'
    manufacturer.save
  end
end
