module Organized
  class AmbassadorTaskAssignmentsController < Organized::BaseController
    before_filter :ensure_ambassador_or_superuser!
    skip_before_filter :ensure_not_ambassador_organization!

    def update
      ambassador_task_assignment = AmbassadorTaskAssignment.find(params[:id])
      completed_at = params[:completed] == "true" ? Time.current : nil

      if ambassador_task_assignment.update(completed_at: completed_at)
        flash[:info] = "Activity status updated."
      else
        flash[:error] = "Could not update activity status. Please try again later."
      end

      redirect_to organization_ambassador_dashboard_url(current_organization)
    end
  end
end
