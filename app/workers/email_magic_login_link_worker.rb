class EmailMagicLoginLinkWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 3

  def perform(user_id)
    user = User.find(user_id)
    unless user.magic_link_token.present?
      raise StandardError, "User #{user_id} does not have a magic_link_token"
    end
    CustomerMailer.magic_login_link_email(user).deliver_now
  end
end
