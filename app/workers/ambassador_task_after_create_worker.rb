class AmbassadorTaskAfterCreateWorker
  include Sidekiq::Worker
  sidekiq_options queue: "high_priority", backtrace: true

  def perform(ambassador_task_id)
    ambassador_task = AmbassadorTask.find(ambassador_task_id)

    AmbassadorTaskAssignmentCreator
      .assign_task_to_all_ambassadors(ambassador_task)
  end
end
