class UpdateAuthTokenWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(id)
    user = User.find(id)
    user.generate_auth_token
    user.save
  end

end