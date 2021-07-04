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
      end
    end
  end
end
