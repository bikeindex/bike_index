class Admin::AmbassadorTaskAssignmentsController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    @ambassador_task_assignments =
      sorted_task_assignments(sort_column, sort_direction)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  private

  def sortable_columns
    %w[completed_at task_title ambassador_name]
  end

  def sorted_task_assignments(column, direction)
    assignments =
      AmbassadorTaskAssignment
        .includes(:ambassador_task, :ambassador)
        .completed

    case column.to_sym
    when :completed_at
      assignments.reorder(completed_at: direction)
    when :task_title
      assignments.reorder("ambassador_tasks.title #{direction}")
    when :ambassador_name
      assignments.reorder("users.name #{direction}")
    else
      assignments.task_ordered
    end
  end
end
