require "rails_helper"

RSpec.describe FacebookAdsIntegration do
  let(:instance) { described_class.new }

  it "gets account" do
    VCR.use_cassette("facebook_ads_integration-get_account", match_requests_on: [:path]) do
      expect(instance.account.name).to eq "Bike Index"
    end
  end

  describe "get_campaign" do
    let(:campaign_id) { "6250389631214" }
    it "get_campaign" do
      VCR.use_cassette("facebook_ads_integration-get_campaign", match_requests_on: [:path]) do
        campaign = instance.get_campaign(campaign_id)
        pp campaign, campaign.objective
        pp campaign.special_ad_categories
        pp campaign.ads.first.creative
      end
    end
  end

  describe "create_campaign" do
    let(:theft_alert) { TheftAlert.new(id: 12) }
    it "creates a campaign" do
      VCR.use_cassette("facebook_ads_integration-create_campaign", match_requests_on: [:path]) do
        campaign = instance.create_campaign(theft_alert)
        expect(campaign).to be_present
      end
    end
  end

  describe "create_ad" do
    let(:theft_alert) { TheftAlert.new(id: 12, facebook_data: {campaign_id: "6250389631214"}) }
    xit "creates an ad" do
      VCR.use_cassette("facebook_ads_integration-create_ad", match_requests_on: [:path]) do
        ad = instance.create_ad(theft_alert)
      end
    end
  end
end
