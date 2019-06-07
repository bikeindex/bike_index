module AmbassadorTaskAssignmentCreator
  def self.assign_task_to_all_ambassadors(ambassador_task_or_id)
    ambassador_task =
      case ambassador_task_or_id
      when AmbassadorTask then ambassador_task_or_id
      when Integer then AmbassadorTask.find(ambassador_task_or_id)
      else raise ArgumentError,
                 "Not an AmbassadorTask or AmbassadorTask id: #{ambassador_task_or_id}"
      end

    already_assigned_ambassador_ids =
      Ambassador
        .includes(:ambassador_task_assignments)
        .where(ambassador_task_assignments: { ambassador_task_id: ambassador_task.id })
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

  def self.assign_all_ambassador_tasks_to(ambassador_or_id)
    ambassador =
      case ambassador_or_id
      when Ambassador then ambassador_or_id
      when User then Ambassador.find(ambassador_or_id.id)
      when Integer then Ambassador.find(ambassador_or_id)
      else raise ArgumentError,
                 "Not an Ambassador or Ambassador id: #{ambassador_or_id}"
      end

    already_assigned_task_ids =
      AmbassadorTask
        .includes(ambassador_task_assignments: :ambassadors)
        .where(ambassador_task_assignments: { ambassador: ambassador })
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
