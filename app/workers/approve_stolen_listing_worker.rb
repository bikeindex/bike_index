class ApproveStolenListingWorker < ApplicationWorker
  sidekiq_options queue: "notify", retry: 1

  TWEETING_DISABLED = ENV["TWITTER_IS_FUCKED"].present?

  def perform(bike_id)
    return if TWEETING_DISABLED
    bike = Bike.find(bike_id)
    new_tweet = TwitterTweeterIntegration.new(bike).create_tweet
    send_stolen_bike_alert_email(bike, new_tweet)
  end

  def send_stolen_bike_alert_email(bike, tweet)
    if bike.current_stolen_record.blank? || tweet.blank?
      raise ArgumentError, error_context(bike, tweet)
    end

    title_string =
      if bike.status_abandoned?
        "We tweeted about the bike you found!"
      else
        "We tweeted about your stolen bike!"
      end

    customer_contact =
      CustomerContact.new(
        body: "EMPTY",
        bike_id: bike.id,
        kind: :stolen_twitter_alerter,
        title: title_string,
        user_email: bike.owner_email,
        creator_email: "bryan@bikeindex.org",
        info_hash: tweet.details_hash
      )

    if customer_contact.save
      EmailStolenBikeAlertWorker.perform_async(customer_contact.id)
    else
      raise ArgumentError, error_context(bike, tweet, customer_contact.errors.full_messages)
    end
  end

  def error_context(bike, tweet, errors = [])
    {
      message: "failed creating alert for stolen listing",
      bike: bike&.id,
      tweet: tweet&.id,
      errors: errors
    }
  end
end
