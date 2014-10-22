class EmailConfirmationWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'email'
  sidekiq_options backtrace: true

  def perform(user_id)
    user = User.find(user_id)
    CustomerMailer.confirmation_email(user).deliver
  end
end
