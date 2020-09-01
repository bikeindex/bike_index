class TweetUpdateWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"

  def perform(tweet_id)
    tweet = Tweet.find tweet_id
    new_response = tweet.twitter_response
    new_response = JSON.parse(new_response) if new_response.is_a?(String)
    tweet.body_html = nil if tweet.body_html == "text"
    tweet.update(twitter_response: new_response)
  end
end
