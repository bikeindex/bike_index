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

      @ambassador_task_assignments =
        current_user
          .ambassador_task_assignments
          .task_ordered
    end

    def resources; end

    def getting_started; end
  end
end
