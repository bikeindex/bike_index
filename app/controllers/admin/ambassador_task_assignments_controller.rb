class Admin::AmbassadorTaskAssignmentsController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    sorted_assignments =
      AmbassadorTaskAssignment
        .sort_by_association(criterion: sort_column, direction: sort_direction)

    @ambassador_task_assignments =
      Kaminari
        .paginate_array(sorted_assignments)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  private

  def sortable_columns
    %w[completed_at task_title ambassador_name]
  end
end
