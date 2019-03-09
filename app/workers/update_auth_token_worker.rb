# Not called in the code, only called if manually expiring
class UpdateAuthTokenWorker
  include Sidekiq::Worker
  sidekiq_options queue: "high_priority", backtrace: true
    
  def perform(id)
    user = User.find(id)
    user.generate_auth_token
    user.save
  end

end