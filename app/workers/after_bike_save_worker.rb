# This will replace WebhookRunner - which is brittle and not flexible enough for what I'm looking for now
# I need to refactor that, but I don't want to right now because I don't want to break existing stuff yet

class AfterBikeSaveWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards", backtrace: true, retry: false
  POST_URL = ENV["BIKE_WEBHOOK_URL"]
  AUTH_TOKEN = ENV["BIKE_WEBHOOK_AUTH_TOKEN"]

  def perform(bike_id)
    bike = Bike.unscoped.where(id: bike_id).first
    return true unless bike.present?
    DuplicateBikeFinderWorker.perform_async(bike_id)
    if bike.present? && bike.listing_order != bike.get_listing_order
      bike.update_attribute :listing_order, bike.get_listing_order
    end
    return true unless bike.stolen # For now, only hooking on stolen bikes
    post_bike_to_webhook(serialized(bike))
  end

  def post_bike_to_webhook(post_body)
    Faraday.new(url: POST_URL).post do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = post_body.to_json
    end
  end

  def serialized(bike)
    {
      auth_token: AUTH_TOKEN,
      bike: BikeV2ShowSerializer.new(bike, root: false).as_json,
      update: bike.created_at > Time.now - 30.seconds
    }
  end
end
