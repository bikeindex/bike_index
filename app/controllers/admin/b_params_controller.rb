class Admin::BParamsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = params[:per_page] || 25
    @pagy, @b_params = pagy(matching_b_params
      .includes(:creator, :organization)
      .reorder("b_params.#{sort_column} #{sort_direction}"), limit: @per_page, page: permitted_page)
  end

  def show
    @b_param = BParam.find(params[:id])
  end

  helper_method :matching_b_params

  private

  def sortable_columns
    %w[created_at updated_at creator_id origin created_bike_id email]
  end

  def matching_b_params
    matching_b_params = BParam
    if params[:search_completeness] == "only_incomplete"
      @search_completeness = "only_incomplete"
      matching_b_params = matching_b_params.without_bike
    elsif params[:search_completeness] == "only_complete"
      @search_completeness = "only_succeeded"
      matching_b_params = matching_b_params.with_bike
    else
      @search_completeness = "all"
    end
    matching_b_params = matching_b_params.where(organization_id: current_organization.id) if params[:organization_id].present?
    matching_b_params = matching_b_params.email_search(params[:query]) if params[:query].present?
    matching_b_params.where(created_at: @time_range)
  end
end
