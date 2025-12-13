class Admin::BaseController < ApplicationController
  before_action :require_index_admin!
  layout "admin"
  DEFAULT_SEARCH_STATUSES = %w[
    stolen with_owner abandoned impounded unregistered_parking_notification
  ].freeze

  # Permit viewing deleted organizations
  def current_organization
    return @current_organization if defined?(@current_organization)
    return @current_organization = nil if params[:organization_id] == "none" # manual nil organization setting

    @current_organization = Organization.unscoped.friendly_find(params[:organization_id])
    set_passive_organization(@current_organization)
  end

  private

  def admin_search_bike_statuses(bikes, default_statuses: nil)
    # Search ignored overrides status searches
    @ignored_only = Binxtils::InputNormalizer.boolean(params[:search_ignored])
    return bikes.ignored if @ignored_only

    @searched_statuses = params.keys.select do |k|
      k.start_with?("search_status_") && Binxtils::InputNormalizer.boolean(params[k])
    end.map { |k| k.gsub(/\Asearch_status_/, "") }
    @default_statuses = default_statuses || DEFAULT_SEARCH_STATUSES
    @searched_statuses = @default_statuses if @searched_statuses.blank?
    @not_default_statuses = @searched_statuses != @default_statuses

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

    bike_statuses = bike_search_statuses(@searched_statuses)
    bikes.where(status: bike_statuses)
  end

  # Match the statuses with bike statuses
  def bike_search_statuses(searched_statuses)
    bike_statuses = searched_statuses.map do |k|
      (k == "unregistered_parking_notification") ? k : "status_#{k}"
    end
    statuses = bike_statuses & Bike.statuses
    # Return all bike statuses if there are no matches (e.g. searching for "deleted_only")
    statuses.any? ? statuses : Bike.statuses
  end
end
