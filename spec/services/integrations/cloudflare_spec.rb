require "rails_helper"

RSpec.describe Integrations::Cloudflare do
  let(:instance) { described_class.new }

  describe "expire_cache" do
    it "purges" do
      # Documentation: https://api.cloudflare.com/#zone-purge-files-by-url
      VCR.use_cassette("cloudflare_integration-expire_cache", match_requests_on: [:path]) do
        result = instance.expire_cache(CreateStolenGeojsonJob.file_url)
        expect(result["success"]).to be_truthy
      end
    end
  end
end
