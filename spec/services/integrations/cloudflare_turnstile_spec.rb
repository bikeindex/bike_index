require "rails_helper"

RSpec.describe Integrations::CloudflareTurnstile do
  describe "configured?" do
    it "is false when keys missing" do
      stub_const("#{described_class}::SITE_KEY", nil)
      stub_const("#{described_class}::SECRET_KEY", nil)
      expect(described_class.configured?).to be false
    end

    context "with both keys" do
      before do
        stub_const("#{described_class}::SITE_KEY", "site")
        stub_const("#{described_class}::SECRET_KEY", "secret")
      end

      it "is true" do
        expect(described_class.configured?).to be true
      end
    end
  end

  describe "verify" do
    context "when not configured" do
      before do
        stub_const("#{described_class}::SITE_KEY", nil)
        stub_const("#{described_class}::SECRET_KEY", nil)
      end

      it "passes through" do
        expect(described_class.verify(nil)).to be true
        expect(described_class.verify("anything")).to be true
      end
    end

    context "when configured" do
      # Cloudflare-published test keys: always-passing site, always-passing secret
      # https://developers.cloudflare.com/turnstile/troubleshooting/testing/
      before do
        stub_const("#{described_class}::SITE_KEY", "1x00000000000000000000AA")
        stub_const("#{described_class}::SECRET_KEY", "1x0000000000000000000000000000000AA")
      end

      it "returns false on blank token" do
        expect(described_class.verify(nil)).to be false
        expect(described_class.verify("")).to be false
      end

      it "verifies a token against the API", vcr: {cassette_name: "cloudflare_turnstile-verify_success"} do
        # XXXX.DUMMY.TOKEN.XXXX is the dummy widget output for the always-passing site key
        expect(described_class.verify("XXXX.DUMMY.TOKEN.XXXX")).to be true
      end

      context "with always-failing secret" do
        before { stub_const("#{described_class}::SECRET_KEY", "2x0000000000000000000000000000000AA") }

        it "returns false", vcr: {cassette_name: "cloudflare_turnstile-verify_failure"} do
          expect(described_class.verify("XXXX.DUMMY.TOKEN.XXXX")).to be false
        end
      end
    end
  end
end
