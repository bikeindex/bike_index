class GetManufacturerLogoWorker < ScheduledWorker
  def self.frequency
    1.week
  end

  def perform(id = nil)
    return enqueue_scheduled_jobs if id.blank?

    manufacturer = Manufacturer.find(id)
    return true if manufacturer.website.blank? || manufacturer.logo.present?

    clearbit_url = "http://logo.clearbit.com/#{manufacturer.website.gsub(/\Ahttps?:\/\//i, "")}?size=400"

    status_response = Net::HTTP.get_response(URI(clearbit_url))
    return true unless status_response.kind_of? Net::HTTPSuccess

    manufacturer.remote_logo_url = clearbit_url
    manufacturer.logo_source = "Clearbit"
    manufacturer.save
  end

  def enqueue_scheduled_jobs
    record_scheduler_started
    Manufacturer.with_websites.pluck(:id).each_with_index do |id, index|
      GetManufacturerLogoWorker.perform_in((5 * index).seconds, id)
    end
  end
end
