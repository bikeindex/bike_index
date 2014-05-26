class ApproveStolenListingWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'stolen'
  sidekiq_options :backtrace => true
    
  def perform(bike_id)
    require 'httparty'
    HTTParty.post(ENV['STOLEN_TWITTERBOT_URL'],
      :body => bike_id,
      :headers => { 'Content-Type' => 'application/json' } )
  end

end