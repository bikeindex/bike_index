require "rails_helper"

RSpec.describe PathSpellingRedirect do
  let(:request) { ActionDispatch::Request.new(Rack::MockRequest.env_for(path)) }

  context "with a dashed spelling of an underscored page" do
    let(:path) { "/for-bike-shops?utm_source=newsletter" }
    it "redirects to the underscored path, keeping the query" do
      expect(described_class.matches?(request)).to be_truthy
      expect(described_class.location(request)).to eq "/for_bike_shops?utm_source=newsletter"
    end
  end

  context "with an underscored spelling of a dashed page" do
    let(:path) { "/ebike_rules/US/CO?manual=1" }
    it "redirects to the dashed path, keeping the query" do
      expect(described_class.matches?(request)).to be_truthy
      expect(described_class.location(request)).to eq "/ebike-rules/US/CO?manual=1"
    end
  end

  context "with the other spelling of a redirect" do
    let(:path) { "/why_donate" }
    it "redirects to the routed spelling" do
      expect(described_class.location(request)).to eq "/why-donate"
    end
  end

  context "with no route under either spelling" do
    let(:path) { "/not-a-page" }
    it "doesn't match" do
      expect(described_class.matches?(request)).to be_falsey
    end
  end

  context "when respelling would change a param" do
    let(:path) { "/o/uc-merced/bulk-imports" }
    it "doesn't match" do
      expect(described_class.matches?(request)).to be_falsey
    end
  end
end
