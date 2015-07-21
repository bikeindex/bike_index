class StolenTwitterbotIntegration
  require 'httparty'
  
  def send_tweet(bike_id)
    options = {api_url: "#{ENV['BASE_URL']}/api/v1/bikes/#{bike_id}", key: ENV['STOLEN_TWITTERBOT_KEY']}
    HTTParty.post(ENV['STOLEN_TWITTERBOT_URL'],
      body: options.to_json,
      headers: { 'Content-Type' => 'application/json' } )
  end

end