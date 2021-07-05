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

  def get_campaign(id)
    FacebookAds::Campaign.get(id)
  end

  def create_campaign(theft_alert)
    account.campaigns.create({
      name: theft_alert.campaign_name,
      objective: "REACH",
      special_ad_categories: []
    })
  end

  def create_ad(theft_alert)
    account.ads.create({

    })
  end

  def new_ad
    {
      bid_strategy: "LOWEST_COST_WITHOUT_CAP",
    }
  end
end
