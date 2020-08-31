class TwitterClient
  include Singleton

  class << self
    def status(*args, &block)
      client.status(*args, &block)
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
end
