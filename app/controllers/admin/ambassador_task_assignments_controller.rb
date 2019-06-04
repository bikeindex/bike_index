class Admin::AmbassadorTaskAssignmentsController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    @ambassador_task_assignments =
      Kaminari
        .paginate_array(sorted_assignments)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  private

  def sortable_columns
    %w[completed_at organization_name task_title ambassador_name]
  end

  def sorted_assignments
    assignments =
      AmbassadorTaskAssignment
        .includes(:ambassador, :ambassador_task)
        .completed

    sort_criterion = params.fetch(:sort, "").to_sym
    direction = params.fetch(:direction, "").to_sym

    case sort_criterion
    when :completed_at
      assignments.reorder(completed_at: direction)
    when :organization_name
      assignments
        .to_a
        .sort_by!(&:organization_name)
        .tap { |arr| arr.reverse! if direction == :desc }
    when :task_title
      assignments.reorder("ambassador_tasks.title #{direction}")
    when :ambassador_name
      assignments.reorder("users.name #{direction}")
    else
      assignments.task_ordered
    end
  end
end
