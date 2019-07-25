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
end
