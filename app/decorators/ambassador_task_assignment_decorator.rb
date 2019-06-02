class AmbassadorTaskAssignmentDecorator < ApplicationDecorator
  delegate_all
  alias ambassador_task_assignment object

  def button_to_toggle_completion_status(current_user, current_organization)
    return unless current_user.ambassador?

    is_complete = ambassador_task_assignment.completed?
    button_label = is_complete ? "Mark Pending" : "Mark Complete"

    h.button_to(
      button_label,
      h.organization_ambassador_task_assignment_url(current_organization, ambassador_task_assignment),
      method: :put,
      params: { completed: !is_complete },
    )
  end
end
