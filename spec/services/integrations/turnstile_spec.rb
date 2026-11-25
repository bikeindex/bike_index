require "rails_helper"

RSpec.describe Integrations::Turnstile do
  describe "challenge?" do
    context "switched on" do
      before { stub_const("Integrations::Turnstile::ENABLED", true) }

      it "asks the domains the spam complaints come from, and nobody else" do
        expect(described_class.challenge?("rider@yahoo.com")).to be_truthy
        expect(described_class.challenge?("rider@hotmail.com")).to be_truthy
        expect(described_class.challenge?("rider@gmail.com")).to be_falsey
        expect(described_class.challenge?(nil)).to be_falsey
      end

      context "a signed-in rider" do
        let(:user) { FactoryBot.create(:user_confirmed, email: "rider@yahoo.com") }
        let!(:second_email) do
          FactoryBot.create(:user_email, user:, email: "rider@hotmail.com", confirmation_token: nil)
        end

        it "asks for every address but the ones they've confirmed" do
          expect(described_class.challenge?("rider@yahoo.com", user:)).to be_falsey
          expect(described_class.challenge?("  Rider@Yahoo.com ", user:)).to be_falsey
          expect(described_class.challenge?(second_email.email, user:)).to be_falsey
          expect(described_class.challenge?("friend@yahoo.com", user:)).to be_truthy
        end

        context "the address isn't confirmed" do
          let(:user) { FactoryBot.create(:user, email: "rider@yahoo.com") }
          let!(:second_email) { nil }

          it "asks - an unconfirmed address is what the challenge is protecting" do
            expect(described_class.challenge?("rider@yahoo.com", user:)).to be_truthy
          end
        end
      end
    end

    context "switched off" do
      before { stub_const("Integrations::Turnstile::ENABLED", false) }

      it "asks nobody" do
        expect(described_class.challenge?("rider@yahoo.com")).to be_falsey
      end
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
