class Admin::AmbassadorTaskAssignmentsController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    matching_assignments =
      AmbassadorTaskAssignment
        .includes(:ambassador_task, ambassador: { memberships: :organization })
        .completed_assignments(filter_params.merge(sort_column => sort_direction))

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
    case
    when params[:organization_id].present?
      @results_filtered = true
      { organization_id: params[:organization_id] }
    when params[:ambassador_task_id]
      @results_filtered = true
      { ambassador_task_id: params[:ambassador_task_id] }
    when params[:ambassador_id]
      @results_filtered = true
      { ambassador_id: params[:ambassador_id] }
    else
      {}
    end
  end
end
