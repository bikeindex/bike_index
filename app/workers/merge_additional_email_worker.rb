class MergeAdditionalEmailWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true

  def perform(user_email_id)
    user_email = UserEmail.find(user_email_id)
    # Merge in bikes, memberships, etc.
  end
end
