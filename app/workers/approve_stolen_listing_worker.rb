class ApproveStolenListingWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'stolen'
  sidekiq_options :backtrace => true
    
  def perform(bike_id)
    require 'httparty'
    root = 'https://bikeindex.org'
    root = 'http://lvh.me:3000' unless Rails.env.production?
    options = {api_url: "#{root}/api/v1/bikes/#{bike_id}", key: ENV['STOLEN_TWITTERBOT_KEY']}
    HTTParty.post(ENV['STOLEN_TWITTERBOT_URL'],
      :body => options.to_json,
      :headers => { 'Content-Type' => 'application/json' } )
  end

end