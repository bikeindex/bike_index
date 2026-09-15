require "rails_helper"

RSpec.describe Integrations::Turnstile do
  # Unconfigured is the default everywhere but production, so the challenge has to be
  # switched on before any of it applies
  def with_keys
    stub_const("Integrations::Turnstile::SITE_KEY", "1x00000000000000000000AA")
    stub_const("Integrations::Turnstile::SECRET_KEY", "1x0000000000000000000000000000000AA")
  end

  describe "challenge?" do
    it "asks the domains the spam complaints come from, and nobody else" do
      with_keys

      expect(described_class.challenge?("rider@yahoo.com")).to be_truthy
      expect(described_class.challenge?("rider@yahoo.co.uk")).to be_truthy
      expect(described_class.challenge?("rider@hotmail.com")).to be_truthy
      expect(described_class.challenge?("rider@gmail.com")).to be_falsey
      expect(described_class.challenge?("rider@bikeindex.org")).to be_falsey
      expect(described_class.challenge?(nil)).to be_falsey
    end

    # A missing key can't be allowed to lock anyone out of registering
    it "asks nobody while it's unconfigured" do
      expect(described_class.challenge?("rider@yahoo.com")).to be_falsey
    end
  end

  describe "verified?" do
    let(:url) { "https://challenges.cloudflare.com/turnstile/v0/siteverify" }
    before { with_keys }

    it "is what Cloudflare says" do
      WebMock.stub_request(:post, url).to_return(body: {success: true}.to_json)
      expect(described_class.verified?("token")).to be_truthy

      WebMock.stub_request(:post, url).to_return(body: {success: false}.to_json)
      expect(described_class.verified?("token")).to be_falsey
    end

    # No stub registered, so reaching the network at all would raise rather than pass
    it "is false for a form that sent no token, without asking" do
      expect(described_class.verified?(nil)).to be_falsey
    end

    # Registration is worth more than the trap, so an outage passes rather than blocks
    it "passes when Cloudflare can't be reached" do
      WebMock.stub_request(:post, url).to_timeout
      expect(described_class.verified?("token")).to be_truthy
    end
  end
end
