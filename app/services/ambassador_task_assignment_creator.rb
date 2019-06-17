module AmbassadorTaskAssignmentCreator
  def self.assign_task_to_all_ambassadors(ambassador_task)
    already_assigned_ambassador_ids =
      Ambassador
        .includes(ambassador_task_assignments: :ambassador_task)
        .where(ambassador_task_assignments: { ambassador_task: ambassador_task })
        .select(:id)

    unassigned_ambassadors =
      Ambassador
        .includes(:ambassador_task_assignments)
        .where
        .not(id: already_assigned_ambassador_ids)
        .references(:ambassador_task_assignments)

    unassigned_ambassadors.find_each do |ambassador|
      ambassador_task.assign_to(ambassador)
    end
  end

  def self.assign_all_ambassador_tasks_to(ambassador)
    ambassador = ambassador.becomes(Ambassador)

    already_assigned_task_ids =
      AmbassadorTask
        .includes(ambassador_task_assignments: :ambassador)
        .where(ambassador_task_assignments: { user_id: ambassador.id })
        .select(:id)

    new_assignments =
      AmbassadorTask
        .includes(:ambassador_task_assignments)
        .where
        .not(id: already_assigned_task_ids)
        .references(:ambassador_task_assignments)

    new_assignments.find_each do |ambassador_task|
      ambassador_task.assign_to(ambassador)
    end
  end
end
