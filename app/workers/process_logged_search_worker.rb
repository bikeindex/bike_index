# NOTE: logged_searches are created by ScheduledStoreLogSearchesWorker
# This adds location data and updates the association

class ProcessLoggedSearchWorker < ApplicationWorker
  sidekiq_options queue: "droppable", retry: 1

  def perform(logged_search_id)
    logged_search = LoggedSearch.find logged_search_id

    assign_user_attributes(logged_search) if logged_search.user.present?
    assign_ip_location(logged_search) if logged_search.ip_address.present?

    logged_search.processed = true
    logged_search.update(updated_at: Time.current) if logged_search.changed?
  end

  private

  def assign_ip_location(logged_search)
    return if logged_search.latitude.present?

    geo_response = Geocoder.searh(logged_search.ip_address)
    location = location_attrs_from_geo_response(geo_response)
    logged_search.attributes = location if location.present?
  end

  def assign_user_attributes(logged_search)
    return if logged_search.user.superuser? || logged_search.organization_id.present?

    logged_search.organization = logged_search.user.organization_prioritized
  end

  def location_attrs_from_geo_response(geo_response)
    if defined?(geo_response.first.data) # Google response
      geo_response.first.data
    elsif defined?(geo_response.first.data_hash) # Maxmind response
      data.data_hash
      pp "dafsadf"
    end
  end
end
