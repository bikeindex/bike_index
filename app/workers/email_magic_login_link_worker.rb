class EmailMagicLoginLinkWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify"
  sidekiq_options backtrace: true

  def perform(user_id)
    user = User.find(user_id)
    raise "Missing magic_link_token token for user: #{user_id}" unless user.magic_link_token.present?
    CustomerMailer.magic_login_link_email(user).deliver_now
  end
end
