class StolenBike::ApproveStolenListingJob < ApplicationJob
  sidekiq_options queue: "notify", retry: 1

  TWEETING_DISABLED = ENV["TWITTER_IS_FUCKED"].present?

  def perform(bike_id)
    return if TWEETING_DISABLED

    bike = Bike.find(bike_id)
    new_social_post = Integrations::TwitterTweeter.new(bike).create_post
    send_stolen_bike_alert_email(bike, new_social_post)
  end

  def send_stolen_bike_alert_email(bike, social_post)
    if bike.current_stolen_record.blank? || social_post.blank?
      raise ArgumentError, error_context(bike, social_post)
    end

    title_string =
      if bike.status_abandoned?
        "We posted about the bike you found!"
      else
        "We posted about your stolen bike!"
      end

    customer_contact =
      CustomerContact.new(
        body: "EMPTY",
        bike_id: bike.id,
        kind: :stolen_twitter_alerter,
        title: title_string,
        user_email: bike.owner_email,
        creator_email: "bryan@bikeindex.org",
        info_hash: social_post.details_hash
      )

    if customer_contact.save
      EmailStolenBikeAlertJob.perform_async(customer_contact.id)
    else
      raise ArgumentError, error_context(bike, social_post, customer_contact.errors.full_messages)
    end
  end

  def error_context(bike, social_post, errors = [])
    {
      message: "failed creating alert for stolen listing",
      bike: bike&.id,
      social_post: social_post&.id,
      errors: errors
    }
  end
end
