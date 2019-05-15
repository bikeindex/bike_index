module Organized
  class AmbassadorDashboardController < Organized::BaseController
    before_filter :ensure_ambassador_or_superuser!

    def index
      @ambassadors =
        Ambassador
          .includes(:memberships)
          .where(memberships: { organization: current_organization })
          .includes(:ambassador_task_assignments)
          .sort_by { |ambassador| -ambassador.percent_complete }

      @ambassador_task_assignments = current_user.ambassador_task_assignments
    end
  end
end
