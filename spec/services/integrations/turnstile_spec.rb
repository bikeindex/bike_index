require "rails_helper"

RSpec.describe Integrations::Turnstile do
  # Cloudflare's published testing secrets, which siteverify answers without an account -
  # 1x… always passes, 2x… always fails
  let(:passing_secret) { "1x0000000000000000000000000000000AA" }
  let(:failing_secret) { "2x0000000000000000000000000000000AA" }

  def with_secret(secret)
    stub_const("Integrations::Turnstile::SITE_KEY", Integrations::Turnstile::TESTING_SITE_KEY)
    stub_const("Integrations::Turnstile::SECRET_KEY", secret)
  end

  # Ownership#spam_risky_email? reads this whether or not the challenge is switched on,
  # so it can't grow an enabled? check the way challenge? has one
  describe "risky_email?" do
    it "matches the domains, configured or not" do
      expect(described_class.risky_email?("rider@yahoo.com")).to be_truthy
      expect(described_class.risky_email?("rider@hotmail.co.uk")).to be_truthy
      expect(described_class.risky_email?("rider@gmail.com")).to be_falsey
      expect(described_class.enabled?).to be_falsey
    end
  end

  describe "challenge?" do
    it "asks the domains the spam complaints come from, and nobody else" do
      with_secret(passing_secret)

      expect(described_class.challenge?("rider@yahoo.com")).to be_truthy
      expect(described_class.challenge?("rider@hotmail.com")).to be_truthy
      expect(described_class.challenge?("rider@gmail.com")).to be_falsey
      expect(described_class.challenge?(nil)).to be_falsey
    end

    # A missing key can't be allowed to lock anyone out of registering
    it "asks nobody while it's unconfigured" do
      expect(described_class.challenge?("rider@yahoo.com")).to be_falsey
    end
  end

  describe "verified?" do
    it "is what Cloudflare says" do
      with_secret(passing_secret)
      VCR.use_cassette("integrations_turnstile-verified") do
        expect(described_class.verified?("XXXX.DUMMY.TOKEN.XXXX")).to be_truthy
      end
    end

    it "is false for a token Cloudflare rejects" do
      with_secret(failing_secret)
      VCR.use_cassette("integrations_turnstile-unverified") do
        expect(described_class.verified?("XXXX.DUMMY.TOKEN.XXXX")).to be_falsey
      end
    end

    # No cassette, so reaching the network at all would raise rather than pass
    it "is false for a form that sent no token, without asking" do
      with_secret(passing_secret)
      expect(described_class.verified?(nil)).to be_falsey
    end
  end
end
