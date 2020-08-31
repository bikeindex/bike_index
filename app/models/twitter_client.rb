class TwitterClient
  include Singleton

  class << self
    def method_missing(method_name, *args, &block)
      instance.client.public_send(method_name, *args, &block) || super
    end
  end

  def client
    @client ||=
      Twitter::REST::Client.new { |config|
        config.consumer_key = ENV.fetch("TWITTER_CONSUMER_KEY")
        config.consumer_secret = ENV.fetch("TWITTER_CONSUMER_SECRET")
        config.access_token = ENV.fetch("TWITTER_ACCESS_TOKEN")
        config.access_token_secret = ENV.fetch("TWITTER_ACCESS_SECRET")
      }
  end
end
