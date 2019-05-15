module Organized
  class AmbassadorTaskAssignmentsController < Organized::BaseController
    before_filter :ensure_ambassador_or_superuser!

    def update
      ambassador_task_assignment = AmbassadorTaskAssignment.find(params[:id])
      completed_at = params[:completed] ? Time.current : nil

      if ambassador_task_assignment.update(completed_at: completed_at)
        render json: ambassador_task_assignment
      else
        render json: {
                 ambassador_task_assignment: ambassador_task_assignment,
                 errors: ambassador_task_assignment.errors.full_messages,
               },
               status: :unprocessable_entity
      end
    end
  end
end
