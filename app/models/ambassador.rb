class Ambassador < User
  default_scope -> { ambassadors }

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
end
