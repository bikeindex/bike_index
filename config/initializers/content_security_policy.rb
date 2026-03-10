# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, "https://fonts.gstatic.com", "http://fonts.gstatic.com", :data
    policy.img_src :self, "https://files.bikeindex.org",
      "https://uploads.bikeindex.org",
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
      "https://syndication.twitter.com", :data, :blob
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
    policy.connect_src :self,
      "https://bikebook.herokuapp.com",
      "https://www.google-analytics.com",
      "https://*.google-analytics.com",
      "https://www.googletagmanager.com",
      "https://maps.googleapis.com",
      "https://translate.googleapis.com", # Google Translate API
      "https://www.facebook.com",
      "https://api.mapbox.com",
      "https://events.mapbox.com",
      "https://*.tiles.mapbox.com",
      "https://cdn.jsdelivr.net",
      "https://api.honeybadger.io"
    policy.worker_src :self, :blob
    policy.frame_src :self,
      "https://www.google.com",
      "https://www.google.ca",
      "https://www.google.de",
      "https://www.google.nl",
      "https://www.google.com.au",
      "https://www.recaptcha.net",
      "https://googleads.g.doubleclick.net",
      "https://www.googletagmanager.com",
      "https://www.youtube.com",
      "https://www.facebook.com",
      "https://web.facebook.com",
      "https://m.facebook.com",
      "https://platform.twitter.com",
      "https://js.stripe.com"
    policy.report_uri -> do
      "https://api.honeybadger.io/v1/browser/csp?api_key=#{ENV["HONEYBADGER_CSP_API_KEY"]}&report_only=true&env=#{Rails.env}&context[user_id]=#{current_user&.id if respond_to?(:current_user)}"
    end
  end

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = true
end
