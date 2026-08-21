require "rails_helper"

RSpec.describe Saml::RequestStore do
  let(:request_id) { "_abc-123" }
  let(:org_slug) { "some-university" }
  let(:token) { described_class.create(request_id:, org_slug:) }

  describe "create" do
    it "issues a distinct expiring token that round trips the transaction" do
      expect(token).to be_present
      expect(RedisPool.conn { |r| r.ttl("saml_request:#{token}") })
        .to be_within(5).of(described_class::TTL.to_i)
      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: nil})
      expect(described_class.create(request_id:, org_slug:)).to_not eq token
    end
  end

  describe "return_to" do
    let(:token) { described_class.create(request_id:, org_slug:, return_to: "/bikes/new") }

    it "travels with the transaction, the callback having no session to read it from" do
      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: "/bikes/new"})
    end
  end

  describe "claim" do
    it "succeeds once, the token being single use" do
      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: nil})
      expect(described_class.claim(token)).to be_nil
    end

    context "a token we never issued" do
      it "is nil rather than raising" do
        expect(described_class.claim(nil)).to be_nil
        expect(described_class.claim("")).to be_nil
        expect(described_class.claim("not-a-real-token")).to be_nil
      end
    end
  end
end
