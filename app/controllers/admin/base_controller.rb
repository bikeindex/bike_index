class Admin::BaseController < ApplicationController
  before_action :require_index_admin!
  layout "admin"

  # Permit viewing deleted organizations
  def current_organization
    return @current_organization if defined?(@current_organization)
    return @current_organization = nil if params[:organization_id] == "none" # manual nil organization setting
    @current_organization = Organization.unscoped.friendly_find(params[:organization_id])
    set_passive_organization(@current_organization)
  end

  def admin_search_bike_statuses(bikes)
    @searched_statuses = params.keys.select do |k|
      k.start_with?("search_status_") && InputNormalizer.boolean(params[k])
    end.map { |k| k.gsub(/\Asearch_status_/, "") }

    @searched_statuses = default_statuses if @searched_statuses.blank?
    @not_default_statuses = @searched_statuses != default_statuses

    if @searched_statuses.include?("example_only")
      bikes = bikes.where(example: true)
    elsif !@searched_statuses.include?("example")
      bikes = bikes.where(example: false)
    end

    if @searched_statuses.include?("spam_only")
      bikes = bikes.where(likely_spam: true)
    elsif !@searched_statuses.include?("spam")
      bikes = bikes.where(likely_spam: false)
    end

    if @searched_statuses.include?("deleted_only")
      bikes = bikes.where.not(deleted_at: nil)
    elsif !@searched_statuses.include?("deleted")
      bikes = bikes.where(deleted_at: nil)
    end

    bike_statuses = (%w[stolen with_owner abandoned impounded] & @searched_statuses)
      .map { |k| "status_#{k}" }
    if @searched_statuses.include?("unregistered_parking_notification")
      bike_statuses << "unregistered_parking_notification"
    end
    bikes.where(status: bike_statuses)
  end
end
