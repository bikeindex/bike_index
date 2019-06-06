class AmbassadorMembershipAfterCreateWorker
  include Sidekiq::Worker
  sidekiq_options queue: "high_priority", backtrace: true

  def perform(membership_id)
    membership = Membership.includes(:organization).find(membership_id)
    return unless membership.ambassador?

    AmbassadorTaskAssignmentCreator
      .assign_all_ambassador_tasks_to(membership.user_id)
  end
end
