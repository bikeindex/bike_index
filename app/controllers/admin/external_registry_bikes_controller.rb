class Admin::ExternalRegistryBikesController < Admin::BaseController
  include SortableTable

  before_action :find_bike, only: %i[show]

  def index
    @per_page = params[:page] || 100
    @pagy, @bikes =
      pagy(matching_bikes
        .reorder("external_registry_bikes.#{sort_column} #{sort_direction}"), limit: @per_page, page: permitted_page)
  end

  def show
  end

  helper_method :registry_types

  private

  def find_bike
    @bike = ExternalRegistryBike.find(params[:id])
  end

  def registry_types
    ["Project529Bike",
      "StopHelingBike",
      "VerlorenOfGevondenBike"]
  end

  def matching_bikes
    return @matching_bikes if defined?(@matching_bikes)

    @matching_bikes = ExternalRegistryBike.all

    if params[:search_serial_normalized].present?
      @matching_bikes = @matching_bikes.where(serial_normalized: params[:search_serial_normalized])
    end

    search_type = params[:search_type]&.split("::")&.last
    @search_type = if registry_types.include?(search_type)
      @matching_bikes = @matching_bikes.where(type: "ExternalRegistryBike::#{search_type}")
      search_type
    else
      "all"
    end

    @search_status = if Bike.statuses.include?(params[:search_status])
      @matching_bikes = @matching_bikes.where(status: params[:search_status])
      params[:search_status]
    else
      "all"
    end

    @matching_bikes = @matching_bikes.where(created_at: @time_range)
  end

  def sortable_columns
    %w[created_at mnfg_name status]
  end
end
