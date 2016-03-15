Rails.application.config.middleware.use OmniAuth::Builder do
  provider :facebook, ENV['FACEBOOK_KEY'], ENV['FACEBOOK_SECRET'], scope: 'email'
  provider :strava, ENV['STRAVA_KEY'], ENV['STRAVA_SECRET'], scope: 'public'
end