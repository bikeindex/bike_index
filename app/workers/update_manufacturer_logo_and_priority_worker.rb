class UpdateManufacturerLogoAndPriorityWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    3.days
  end

  def perform(id = nil)
    if id.blank?
      enqueue_scheduled_jobs
    else
      manufacturer = Manufacturer.find(id)
      get_manufacturer_logo(manufacturer) ||
        update_priority_if_changed(manufacturer)
    end
  end

  def enqueue_scheduled_jobs
    Manufacturer.pluck(:id).each_with_index do |id, index|
      self.class.perform_in((5 * index).seconds, id)
    end
  end

  def update_priority_if_changed(manufacturer)
    return true if manufacturer.priority == manufacturer.calculated_priority
    manufacturer.update(updated_at: Time.current)
  end

  def get_manufacturer_logo(manufacturer)
    return false if manufacturer.website.blank? || manufacturer.logo.present?

    clearbit_url = "https://logo.clearbit.com/#{manufacturer.website.gsub(/\Ahttps?:\/\//i, "")}?size=400"

    status_response = Net::HTTP.get_response(URI(clearbit_url))

    return false unless status_response.is_a?(Net::HTTPSuccess)

    manufacturer.update!(remote_logo_url: clearbit_url, logo_source: "Clearbit")
  end
end
