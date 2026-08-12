# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# GA4 shards the /g/collect beacon across regional hosts and falls back to an image when it
# can't fetch, so every host belongs in both img_src and connect_src. `*.` never matches the
# bare domain, hence each pair
GOOGLE_ANALYTICS_HOSTS = ["https://*.google-analytics.com", "https://analytics.google.com",
  "https://*.analytics.google.com", "https://stats.g.doubleclick.net"].freeze

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, "https://fonts.gstatic.com", "http://fonts.gstatic.com", "https://themes.googleusercontent.com", :data
    # Blobs serve from the bucket's own domain, one per environment, and an unlisted host renders
    # nothing. Duplicates BlobUrl because this runs before autoloading; blob_url_spec catches drift
    policy.img_src :self, "https://files.bikeindex.org",
      ENV.fetch("ACTIVE_STORAGE_HOST", "https://uploads.bikeindex.org"),
      ENV.fetch("ACTIVE_STORAGE_HOST_DEV", "https://dev-uploads.bikeindex.org"),
      ENV.fetch("ACTIVE_STORAGE_HOST_TEST", "https://test-uploads.bikeindex.org"),
      "https://maps.bikeindex.org",
      "https://bikebook.s3.amazonaws.com",
      "https://www.googletagmanager.com",
      "https://maps.googleapis.com",
      "https://maps.gstatic.com",
      # Google Translate injects images when users translate the page in Chrome
      "https://fonts.gstatic.com",
      "https://translate.google.com",
      "https://www.facebook.com",
      "https://connect.facebook.net",
      "https://pbs.twimg.com",
      "https://www.googleadservices.com",
      "https://syndication.twitter.com", *GOOGLE_ANALYTICS_HOSTS, :data, :blob
    policy.object_src :none
    # unsafe_eval is required for application_revised.js jQuery - remove it when possible!
    policy.script_src :self, :unsafe_inline, :unsafe_eval,
      "https://widget.bikeindex.org",
      "https://www.googletagmanager.com",
      "https://www.google-analytics.com",
      "https://www.googleadservices.com",
      "https://maps.googleapis.com",
      "https://connect.facebook.net",
      "https://platform.twitter.com",
      "https://api.mapbox.com",
      "https://cdn.jsdelivr.net",
      "https://js.stripe.com"
    policy.style_src :self, :unsafe_inline,
      "https://fonts.googleapis.com",
      "https://www.gstatic.com", # Google Translate styles
      "https://cdn.jsdelivr.net",
      "https://api.mapbox.com"
    policy.connect_src :self, *GOOGLE_ANALYTICS_HOSTS,
      "https://*.tiles.mapbox.com",
      "https://api.honeybadger.io",
      "https://api.mapbox.com",
      "https://bikebook.herokuapp.com",
      "https://cdn.jsdelivr.net",
      "https://events.mapbox.com",
      # Our own image CDNs — third-party scripts (Facebook Pixel) fetch bike photos, not just <img> them
      "https://files.bikeindex.org",
      # Self-hosted MapLibre basemap tiles for the registration map (range requests)
      "https://maps.bikeindex.org",
      "https://maps.googleapis.com",
      # A direct upload PUTs to a presigned R2 url, not the CDN - wildcard because the presigner
      # addresses the bucket virtual-host style: <bucket>.<account>.r2.cloudflarestorage.com
      "https://*.r2.cloudflarestorage.com",
      "https://translate.googleapis.com", # Google Translate API
      "https://uploads.bikeindex.org",
      "https://www.facebook.com",
      "https://www.google.com", # GA4 region-redirects some /g/collect beacons here
      "https://www.googletagmanager.com"
    policy.worker_src :self, :blob
    policy.frame_src :self,
      "https://www.google.com",
      # Google Ads conversion tracking iframes use country-specific Google domains
      "https://www.google.ca",
      "https://www.google.co.id",
      "https://www.google.co.uk",
      "https://www.google.com.au",
      "https://www.google.com.br",
      "https://www.google.de",
      "https://www.google.es",
      "https://www.google.fr",
      "https://www.google.it",
      "https://www.google.nl",
      "https://www.google.co.in",
      "https://www.google.co.jp",
      "https://www.google.com.mx",
      "https://www.recaptcha.net",
      "https://googleads.g.doubleclick.net",
      "https://www.googletagmanager.com",
      "https://www.youtube.com",
      "https://www.facebook.com",
      "https://web.facebook.com",
      "https://m.facebook.com",
      "https://platform.twitter.com",
      "https://js.stripe.com"
    policy.report_uri "/csp_reports"
  end

  config.content_security_policy_report_only = false
end
