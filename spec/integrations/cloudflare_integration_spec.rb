require "rails_helper"

RSpec.describe CloudflareIntegration do
  describe "purge_cache" do
    # Note: not really testing this, mostly just recording the cassette and verifying the request happens
    it "purges" do
      VCR.use_cassette("cloudflare_integration", match_requests_on: [:path]) do
      end
    end
  end
end
