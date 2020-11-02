class Admin::FailedBikesController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params.fetch(:page, 1)
    per_page = params.fetch(:per_page, 25)

    @b_params = matching_b_params
        .includes(:creator)
        .reorder("b_params.#{sort_column} #{sort_direction}")
        .page(page)
        .per(per_page)
  end

  def show
    @b_param = BParam.find(params[:id])
  end

  helper_method :matching_b_params

  private

  def sortable_columns
    %w[created_at updated_at email]
  end

  def matching_b_params
    matching_b_params = BParam
    if params[:search_failedness] == "only_failed"
      matching_b_params = matching_b_params.without_bike
    elsif params[:search_failedness] == "only_created"
      matching_b_params = matching_b_params.with_bike
    end
    matching_b_params.where(created_at: @time_range)
  end
end
