require "rails_helper"

RSpec.describe Integrations::Turnstile do
  describe "challenge?" do
    context "configured" do
      before do
        stub_const("Integrations::Turnstile::SITE_KEY", Integrations::Turnstile::TESTING_SITE_KEY)
        stub_const("Integrations::Turnstile::SECRET_KEY", "1x0000000000000000000000000000000AA")
      end

      it "asks the domains the spam complaints come from, and nobody else" do
        expect(described_class.challenge?("rider@yahoo.com")).to be_truthy
        expect(described_class.challenge?("rider@hotmail.com")).to be_truthy
        expect(described_class.challenge?("rider@gmail.com")).to be_falsey
        expect(described_class.challenge?(nil)).to be_falsey
      end
    end

    it "asks nobody while it's unconfigured" do
      expect(described_class.challenge?("rider@yahoo.com")).to be_falsey
      expect(described_class.site_key).to be_blank
    end
  end

  describe "verified?" do
    # Cloudflare's published testing secrets: 1x… always passes, 2x… always fails
    let(:secret) { "1x0000000000000000000000000000000AA" }
    before { stub_const("Integrations::Turnstile::SECRET_KEY", secret) }

    it "is what Cloudflare says" do
      VCR.use_cassette("integrations_turnstile-verified") do
        expect(described_class.verified?("XXXX.DUMMY.TOKEN.XXXX")).to be_truthy
      end
    end

    context "a token Cloudflare rejects" do
      let(:secret) { "2x0000000000000000000000000000000AA" }

      it "is false" do
        VCR.use_cassette("integrations_turnstile-unverified") do
          expect(described_class.verified?("XXXX.DUMMY.TOKEN.XXXX")).to be_falsey
        end
      end
    end

    # No cassette, so reaching the network at all would raise rather than pass
    it "is false for a form that sent no token, without asking" do
      expect(described_class.verified?(nil)).to be_falsey
    end
  end
end
