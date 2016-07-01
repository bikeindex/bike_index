class AfterUserChangeWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, retry: false
  # This is called when a user is updated
  # Or when a bike a user owns is updated

  def perform(user_id)
    WebhookRunner.new.after_user_update(user_id)
  end
end
