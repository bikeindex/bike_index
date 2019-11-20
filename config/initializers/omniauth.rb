Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, ENV["FACEBOOK_KEY"], ENV["FACEBOOK_SECRET"], scope: "email"
  provider :strava, ENV["STRAVA_KEY"], ENV["STRAVA_SECRET"], scope: "public"
  provider :twitter, ENV["TWITTER_CONSUMER_KEY"], ENV["TWITTER_CONSUMER_SECRET"],
           authorize_params: { force_login: true }
  # GLOBALID_PRIVATE_KEY extra escaped, clean up a little
  provider :globalid, ENV["GLOBALID_CLIENT_ID"], ENV["GLOBALID_CLIENT_SECRET"],
    scope: "openid", decrypt_pii_on_login: true, acrc_id: ENV["ACRC_ID"],
    provider_ignores_state: true, private_key_pass: ENV["GLOBALID_PRIVATE_KEY_PASS"],
    private_key: ENV["GLOBALID_PRIVATE_KEY"].gsub("\\n", "\n").gsub("\"", "")
end
