class StolenBike::ApproveStolenListingJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 1

  TWEETING_DISABLED = ENV["TWITTER_IS_FUCKED"].present?

  def perform(bike_id)
    return if TWEETING_DISABLED

    bike = Bike.find(bike_id)
    new_post = Integrations::SocialPoster.new(bike).create_post
    send_stolen_bike_alert_email(bike, new_post)
  end

  def send_stolen_bike_alert_email(bike, post)
    if bike.current_stolen_record.blank? || post.blank?
      raise ArgumentError, error_context(bike, post)
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
        info_hash: post.details_hash
      )

    if customer_contact.save
      EmailStolenBikeAlertJob.perform_async(customer_contact.id)
    else
      raise ArgumentError, error_context(bike, post, customer_contact.errors.full_messages)
    end
  end

  def error_context(bike, post, errors = [])
    {
      message: "failed creating alert for stolen listing",
      bike: bike&.id,
      post: post&.id,
      errors: errors
    }
  end
end
