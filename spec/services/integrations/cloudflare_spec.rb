require "rails_helper"

RSpec.describe Integrations::Cloudflare do
  describe ".expire_cache" do
    it "purges" do
      # Documentation: https://api.cloudflare.com/#zone-purge-files-by-url
      VCR.use_cassette("cloudflare_integration-expire_cache", match_requests_on: [:path]) do
        result = described_class.expire_cache(CreateStolenGeojsonJob.file_url)
        expect(result["success"]).to be_truthy
      end
    end

    context "when API_TOKEN is blank" do
      before { stub_const("Integrations::Cloudflare::API_TOKEN", "") }

      it "returns nil without making an HTTP request" do
        expect(described_class.expire_cache(CreateStolenGeojsonJob.file_url)).to be_nil
      end
    end
  end
end
