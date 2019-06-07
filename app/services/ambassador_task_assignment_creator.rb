module AmbassadorTaskAssignmentCreator
  def self.assign_task_to_all_ambassadors(ambassador_task)
    already_assigned_ambassador_ids =
      Ambassador
        .includes(ambassador_task_assignments: :ambassador_task)
        .where(ambassador_task_assignments: { ambassador_task: ambassador_task })
        .select(:id)

    new_assignments =
      Ambassador
        .includes(:ambassador_task_assignments)
        .where
        .not(id: already_assigned_ambassador_ids)
        .pluck(:id)
        .map { |ambassador_id| { user_id: ambassador_id, ambassador_task_id: ambassador_task.id } }

    AmbassadorTaskAssignment.import(new_assignments, validate: true)
  end

  def self.assign_all_ambassador_tasks_to(ambassador)
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
        .pluck(:id)
        .map { |t_id| { ambassador_task_id: t_id, user_id: ambassador.id } }

    AmbassadorTaskAssignment.import(new_assignments, validate: true)
  end
end
