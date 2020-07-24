class Admin::AmbassadorTaskAssignmentsController < Admin::BaseController
  include SortableTable

  def index
    matching_assignments =
      AmbassadorTaskAssignment
        .includes(:ambassador_task, ambassador: {memberships: :organization})
        .completed_assignments(filters: filter_params, sort: {sort_column => sort_direction})

    @ambassador_task_assignments =
      Kaminari
        .paginate_array(matching_assignments)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  private

  def sortable_columns
    %w[completed_at organization_name ambassador_task_title ambassador_name]
  end

  def filter_params
    params
      .permit(:search_organization_id, :search_ambassador_task_id, :search_ambassador_id)
      .to_h
      .map { |k, v| [k[/(?<=search_).+/].to_sym, v] }
      .to_h
  end

  def organization_filter
    params[:search_organization_id]
  end

  helper_method :organization_filter
end
