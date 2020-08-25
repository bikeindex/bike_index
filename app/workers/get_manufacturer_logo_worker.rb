class GetManufacturerLogoWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    1.week
  end

  def perform(id = nil)
    if id.blank?
      enqueue_scheduled_jobs
    else
      get_manufacturer_logo(id)
    end
  end

  def enqueue_scheduled_jobs
    Manufacturer.with_websites.pluck(:id).each_with_index do |id, index|
      GetManufacturerLogoWorker.perform_in((5 * index).seconds, id)
    end
  end

  def get_manufacturer_logo(manufacturer_id)
    manufacturer = Manufacturer.find(manufacturer_id)
    return true if manufacturer.website.blank? || manufacturer.logo.present?

    clearbit_url = "http://logo.clearbit.com/#{manufacturer.website.gsub(/\Ahttps?:\/\//i, "")}?size=400"

    status_response = Net::HTTP.get_response(URI(clearbit_url))
    return true unless status_response.is_a? Net::HTTPSuccess

    manufacturer.remote_logo_url = clearbit_url
    manufacturer.logo_source = "Clearbit"
    manufacturer.save
  end
end
