class FacebookAdsIntegration
  # SECRET = ENV["FACEBOOK_AD_SECRET"] # Not needed unless setting is updated in app dashboard on facebook
  # To get an app token go to: https://developers.facebook.com/tools/explorer/ and create one
  # THEN - go to token debugger and mark it long lived
  TOKEN = ENV["FACEBOOK_AD_TOKEN"]
  ACCOUNT_ID = 62935371

  FacebookAds.configure do |config|
    config.access_token = TOKEN
  end

  require "facebook_ads"

  def account
    FacebookAds::AdAccount.get("act_#{ACCOUNT_ID}")
  end

  def list_campaigns

  end
end
