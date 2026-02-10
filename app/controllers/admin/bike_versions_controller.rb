class Admin::BikeVersionsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_bike_versions.includes(:bike, :owner).reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  def show
    @bike_version = BikeVersion.unscoped.find(params[:id])
    @bike = @bike_version.bike
  end

  helper_method :matching_bike_versions

  protected

  def sortable_columns
    %w[created_at bike_id owner_id visibility]
  end

  def sortable_opts
    "bike_versions.#{sort_column} #{sort_direction}"
  end

  def earliest_period_date
    Time.at(1641016800) # 2022-01-01 00:00 - first bike version
  end

  def matching_bike_versions
    bike_versions = BikeVersion.unscoped

    if params[:search_bike_id].present?
      @bike = Bike.unscoped.find_by(id: params[:search_bike_id])
      bike_versions = bike_versions.where(bike_id: params[:search_bike_id])
    end

    if params[:user_id].present?
      bike_versions = bike_versions.where(owner_id: user_subject&.id || params[:user_id])
    end

    if params[:search_visibility].present?
      bike_versions = bike_versions.where(visibility: params[:search_visibility])
    end

    bike_versions.where(created_at: @time_range)
  end
end
