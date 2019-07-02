class Admin::PartialBikesController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @b_params = matching_b_params.reorder("b_params.#{sort_column} #{sort_direction}").page(page).per(per_page)
  end

  protected

  def sortable_columns
    %w[created_at updated_at creator_id origin created_bike_id email]
  end

  def matching_b_params
    @search_with_bike = ParamsNormalizer.boolean(params[:search_with_bike])
    @search_without_bike = ParamsNormalizer.boolean(params[:search_without_bike])
    b_params = BParam
    b_params = b_params.with_bike if @search_with_bike
    b_params = b_params.without_bike if @search_without_bike
    b_params = b_params.email_search(params[:query]) if params[:query].present?
    b_params
  end
end
