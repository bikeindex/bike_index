class Admin::AmbassadorTaskAssignmentsController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    @ambassador_task_assignments =
      AmbassadorTaskAssignment
        .sort_by_association(criterion: sort_column, direction: sort_direction)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  private

  def sortable_columns
    %w[completed_at task_title ambassador_name]
  end
end
