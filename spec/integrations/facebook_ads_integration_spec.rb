require "rails_helper"

RSpec.describe FacebookAdsIntegration do
  let(:instance) { described_class.new }

  it "gets account" do
    VCR.use_cassette("facebook_ads_integration-get_account", match_requests_on: [:path]) do
      # pp instance.account.name
    end
  end

  it "gets campaigns" do
    VCR.use_cassette("facebook_ads_integration-get_campaigns", match_requests_on: [:path]) do
      # pp instance.account
    end
  end
end
