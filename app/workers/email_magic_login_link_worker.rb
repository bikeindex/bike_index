class EmailMagicLoginLinkWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: false # Don't retry, because it will reset the magic link token

  def perform(user_id)
    user = User.find(user_id)
    unless user.magic_link_token.present?
      user.update_auth_token("magic_link_token")
      user.reload
    end
    CustomerMailer.magic_login_link_email(user).deliver_now
  end
end
