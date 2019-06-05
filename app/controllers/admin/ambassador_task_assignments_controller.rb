class Admin::AmbassadorTaskAssignmentsController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    matching_assignments =
      AmbassadorTaskAssignment
        .includes(:ambassador_task, ambassador: { memberships: :organization })
        .completed_assignments(filters: filter_params, sort: { sort_column => sort_direction })

    @ambassador_task_assignments =
      Kaminari
        .paginate_array(matching_assignments)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  private

  def sortable_columns
    %w[completed_at organization_name task_title ambassador_name]
  end

  def filter_params
    {}.tap do |h|
      h[:organization_id] = organization_filter if organization_filter.present?
      h[:ambassador_task_id] = params[:search_ambassador_task_id] if params[:search_ambassador_task_id].present?
      h[:ambassador_id] = params[:search_ambassador_id] if params[:search_ambassador_id].present?
    end
  end

  def organization_filter
    params[:search_organization_id]
  end

  helper_method :organization_filter
end
