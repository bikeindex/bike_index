Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, ENV["FACEBOOK_KEY"], ENV["FACEBOOK_SECRET"], scope: "email"
  provider :strava, ENV["STRAVA_KEY"], ENV["STRAVA_SECRET"], scope: "public"
  provider :globalid, ENV["GLOBALID_KEY"], ENV["GLOBALID_KEY"], scope: "public"
  provider :twitter, ENV["TWITTER_CONSUMER_KEY"], ENV["TWITTER_CONSUMER_SECRET"],
           authorize_params: { force_login: true }
end
