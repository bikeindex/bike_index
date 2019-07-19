# Not called in the code, only called if manually expiring
class UpdateAuthTokenWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform(id)
    user = User.find(id)
    user.generate_auth_token("auth_token")
    user.save
  end
end
