# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src :self, "https://fonts.gstatic.com", :data
    policy.img_src :self, "https://files.bikeindex.org", "https://uploads.bikeindex.org", "https://www.facebook.com", "https://www.googletagmanager.com", "https://pbs.twimg.com", :data
    policy.object_src :none
    policy.script_src :self, :unsafe_inline,
      "https://www.googletagmanager.com",
      "https://www.google-analytics.com",
      "https://cdn.jsdelivr.net",
      "https://js.stripe.com",
      "https://platform.twitter.com",
      "https://connect.facebook.net",
      "https://maps.googleapis.com",
      "https://api.mapbox.com"
    policy.style_src :self, :unsafe_inline,
      "https://fonts.googleapis.com",
      "https://api.mapbox.com",
      "https://cdn.jsdelivr.net"
    policy.connect_src :self,
      "https://www.google-analytics.com",
      "https://www.googletagmanager.com",
      "https://api.mapbox.com",
      "https://*.tiles.mapbox.com"
    policy.frame_src :self,
      "https://js.stripe.com",
      "https://www.facebook.com",
      "https://www.googletagmanager.com",
      "https://www.youtube.com"
  end

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = true
end
