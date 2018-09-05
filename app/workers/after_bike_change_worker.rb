# This replaces WebhookRunner - which is brittle and not flexible enough for what I'm looking for now
# Basically I need to refactor that, but I don't want to right now because I hate myself
# Also worth noting - this should be combined in some way with AfterBikeSaveWorker

class AfterBikeChangeWorker
  include Sidekiq::Worker
  sidekiq_options queue: "afterwards"
  sidekiq_options backtrace: true
  POST_URL = ENV["BIKE_WEBHOOK_URL"]
  AUTH_TOKEN = ENV["BIKE_WEBHOOK_AUTH_TOKEN"]

  def perform(id)
    bike = Bike.where(id: id).first
    return true unless bike.present? && bike.stolen
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
