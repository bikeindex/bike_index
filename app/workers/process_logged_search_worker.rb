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

    logged_search.attributes = GeocodeHelper.assignable_address_hash_for(logged_search.ip_address)
  end

  def assign_user_attributes(logged_search)
    return if logged_search.user.superuser? || logged_search.organization_id.present?

    logged_search.organization = logged_search.user.organization_prioritized
  end
end
