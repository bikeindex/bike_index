class Ambassador < User
  default_scope -> { ambassadors }

  # Return all of the receiver's `AmbassadorTaskAssignment`s that are completed
  # and locked.
  def activities_completed
    ambassador_task_assignments
      .includes(:ambassador_task)
      .locked_completed
      .task_ordered
  end

  # Return all of the receiver's `AmbassadorTaskAssignment`s that have not been
  # completed or have been completed but aren't locked.
  def activities_pending
    ambassador_task_assignments
      .includes(:ambassador_task)
      .pending_completion
      .task_ordered
  end

  def percent_complete
    return 0.0 if ambassador_task_assignments.empty?
    (completed_tasks_count / tasks_count.to_f).round(2)
  end

  def progress_count
    "#{completed_tasks_count}/#{tasks_count}"
  end

  def completed_tasks_count
    ambassador_task_assignments.completed.count
  end

  def tasks_count
    ambassador_task_assignments.count
  end

  def ambassador_organizations
    organizations.ambassador
  end

  def current_ambassador_organization
    most_recent_ambassador_membership =
      memberships
        .ambassador_organizations
        .reorder(created_at: :desc)
        .limit(1)

    organizations
      .ambassador
      .where(id: most_recent_ambassador_membership.select(:organization_id))
      .first
  end
end
