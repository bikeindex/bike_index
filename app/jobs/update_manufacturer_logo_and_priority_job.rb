# frozen_string_literal: true

class UpdateManufacturerLogoAndPriorityJob < ScheduledJob
  prepend ScheduledJobRecorder

  API_KEY = ENV["LOGO_API_TOKEN"]

  def self.frequency
    3.days
  end

  def self.logo_url(manufacturer)
    "https://img.logo.dev/#{manufacturer.website.gsub(/\Ahttps?:\/\//i, "")}?size=400&fallback=404&token=#{API_KEY}"
  end

  def perform(id = nil)
    if id.blank?
      enqueue_scheduled_jobs
    else
      manufacturer = Manufacturer.find(id)
      get_manufacturer_logo(manufacturer)
      update_priority_if_changed(manufacturer)
    end
  end

  def enqueue_scheduled_jobs
    Manufacturer.pluck(:id).each_with_index do |id, index|
      self.class.perform_in((5 * index).seconds, id)
    end
  end

  def update_priority_if_changed(manufacturer)
    return if manufacturer.priority == manufacturer.calculated_priority

    manufacturer.update(updated_at: Time.current)
  end

  def get_manufacturer_logo(manufacturer)
    return if manufacturer.website.blank? || manufacturer.logo.present?

    logo_url = self.class.logo_url(manufacturer)

    status_response = Net::HTTP.get_response(URI(logo_url))

    return if status_response.is_a?(Net::HTTPNotFound)

    manufacturer.update!(remote_logo_url: logo_url, logo_source: "Logo.dev")
  end
end
