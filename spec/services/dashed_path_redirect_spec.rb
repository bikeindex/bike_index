require "rails_helper"

RSpec.describe DashedPathRedirect do
  let(:request) { ActionDispatch::Request.new(Rack::MockRequest.env_for(path)) }

  context "with a page's dashed spelling" do
    let(:path) { "/ebike-rules/US/CO?manual=1" }
    it "redirects to the underscored path, keeping the query" do
      expect(described_class.matches?(request)).to be_truthy
      expect(described_class.location(request)).to eq "/ebike_rules/US/CO?manual=1"
    end
  end

  context "with a redirect's dashed spelling" do
    let(:path) { "/why-donate" }
    it "matches" do
      expect(described_class.matches?(request)).to be_truthy
    end
  end

  context "with no route under either spelling" do
    let(:path) { "/not-a-page" }
    it "doesn't match" do
      expect(described_class.matches?(request)).to be_falsey
    end
  end

  context "when the underscores would change a param" do
    let(:path) { "/o/uc-merced/bulk-imports" }
    it "doesn't match" do
      expect(described_class.matches?(request)).to be_falsey
    end
  end
end
