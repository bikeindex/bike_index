class TwitterClient
  include Singleton

  class << self
    def method_missing(method_name, *args, &block)
      instance.client.public_send(method_name, *args, &block)
    end
  end

  def client
    @client ||=
      Twitter::REST::Client.new do |config|
        config.consumer_key = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token = ENV["TWITTER_OAUTH_TOKEN"]
        config.access_token_secret = ENV["TWITTER_OAUTH_TOKEN_SECRET"]
      end
  end
end
