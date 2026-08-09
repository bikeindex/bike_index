require "rails_helper"

RSpec.describe EmailReceiver do
  describe "for_mail" do
    let(:mail) { Mail.new(from: "someone@example.com", to: "Bugs@bikeindex.org", subject: "Hi", body: "Hello") }

    it "normalizes the address it was sent to" do
      expect(described_class.for_mail(mail)).to eq "bugs@bikeindex.org"
    end

    context "addressed to someone else too" do
      let(:mail) { Mail.new(from: "someone@example.com", to: ["friend@example.com", "contact@bikeindex.org"]) }

      it "prefers our address" do
        expect(described_class.for_mail(mail)).to eq "contact@bikeindex.org"
      end
    end

    context "with our address cc'd" do
      let(:mail) { Mail.new(from: "someone@example.com", to: "friend@example.com", cc: "Support@bikeindex.org") }

      it "receives the cc" do
        expect(described_class.for_mail(mail)).to eq "support@bikeindex.org"
      end
    end

    context "with an X-Original-To header" do
      let(:mail) do
        Mail.new(:from => "someone@example.com", :to => "friend@example.com",
          "X-Original-To" => "contact@bikeindex.org")
      end

      it "receives the envelope recipient" do
        expect(described_class.for_mail(mail)).to eq "contact@bikeindex.org"
      end
    end

    context "without an address of ours" do
      let(:mail) { Mail.new(from: "someone@example.com", to: "Friend@example.com") }

      it "falls back to the first recipient" do
        expect(described_class.for_mail(mail)).to eq "friend@example.com"
      end

      context "without any recipient" do
        let(:mail) { Mail.new(from: "someone@example.com") }

        it "is nil" do
          expect(described_class.for_mail(mail)).to be_nil
        end
      end
    end
  end
end
