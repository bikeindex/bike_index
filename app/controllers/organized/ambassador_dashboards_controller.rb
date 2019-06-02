module Organized
  class AmbassadorDashboardsController < Organized::BaseController
    before_filter :ensure_ambassador_or_superuser!
    skip_before_filter :ensure_not_ambassador_organization!

    def show
      @ambassadors =
        Ambassador
          .includes(:memberships)
          .where(memberships: { organization: current_organization })
          .includes(:ambassador_task_assignments)
          .sort_by { |ambassador| -ambassador.percent_complete }

      if current_user.ambassador?
        current_ambassador = Ambassador.find(current_user.id).decorate
        @suggested_activities = current_ambassador.suggested_activities
        @completed_activities = current_ambassador.completed_activites
      else
        @suggested_activities = AmbassadorTask.task_ordered
        @completed_activities = current_ambassador.completed_activites
      end
    end

    def resources; end

    def getting_started; end
  end
end
