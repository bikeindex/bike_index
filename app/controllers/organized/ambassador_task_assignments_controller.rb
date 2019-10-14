module Organized
  class AmbassadorTaskAssignmentsController < Organized::BaseController
    before_filter :ensure_ambassador_authorized!
    skip_before_filter :ensure_not_ambassador_organization!

    def update
      ambassador_task_assignment = AmbassadorTaskAssignment.find(params[:id])
      completed_at = params[:completed] == "true" ? Time.current : nil

      if ambassador_task_assignment.update_attributes(completed_at: completed_at)
        flash[:info] = translation(:status_updated)
      else
        flash[:error] = translation(:could_not_update)
      end

      redirect_to organization_ambassador_dashboard_url(current_organization)
    end
  end
end
