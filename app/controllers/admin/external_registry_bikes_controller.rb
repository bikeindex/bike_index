class Admin::ExternalRegistryBikesController < Admin::BaseController
  include SortableTable
  before_action :find_bike, only: %i[show]

  def index
    @page = params[:page] || 1
    @bikes =
      matching_bikes
        .reorder("external_registry_bikes.#{sort_column} #{sort_direction}")
        .page(@page)
        .per(params[:per_page] || 100)
  end

  def show
  end

  private

  def find_bike
    @bike = ExternalRegistryBike.find(params[:id])
  end

  def matching_bikes
    return @matching_bikes if defined?(@matching_bikes)

    @matching_bikes = ExternalRegistryBike.all

    if params[:search_serial_normalized].present?
      @matching_bikes = @matching_bikes.where(serial_normalized: params[:search_serial_normalized])
    end

    if params[:type].present?
      @matching_bikes = @matching_bikes.where(type: params[:type])
    end

    @matching_bikes
  end

  def sortable_columns
    %w[created_at mnfg_name]
  end
end
