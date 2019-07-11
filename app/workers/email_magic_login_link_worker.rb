class EmailMagicLoginLinkWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify"
  sidekiq_options backtrace: true

  def perform(user_id)
    user = User.find(user_id)
    CustomerMailer.magic_login_link_email(@organization).deliver_now
  end
end
