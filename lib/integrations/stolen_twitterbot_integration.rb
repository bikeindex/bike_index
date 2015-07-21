class StolenTwitterbotIntegration
  require 'httparty'
  
  def send_tweet(bike_id)
    options = {api_url: "#{ENV['BASE_URL']}/api/v1/bikes/#{bike_id}", key: ENV['STOLEN_TWITTERBOT_KEY']}
    HTTParty.post(ENV['STOLEN_TWITTERBOT_URL'],
      body: options.to_json,
      headers: { 'Content-Type' => 'application/json' } )

    # begin
    #   uri = URI("http://bikebook.io#{method}")
    #   uri.query = URI.encode_www_form(query)
    #   res = Net::HTTP.get_response(uri)
    # rescue
    #   return nil
    # end
    # return nil unless res.is_a?(Net::HTTPSuccess)

    # response = JSON.parse(res.body)
    # return response if response.kind_of?(Array)
    # response.with_indifferent_access     
  end
  
end