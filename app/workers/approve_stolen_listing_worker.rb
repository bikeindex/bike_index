class ApproveStolenListingWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'stolen'
  sidekiq_options :backtrace => true
    
  def perform(bike_id)
    require 'httparty'
    options = {api_url: api_v1_url(bike_id), key: ENV['STOLEN_TWITTERBOT_KEY']}
    HTTParty.post(ENV['STOLEN_TWITTERBOT_URL'],
      :body => options.to_json
      :headers => { 'Content-Type' => 'application/json' } )
  end

end