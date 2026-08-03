require "rails_helper"

RSpec.describe Saml::RequestStore do
  let(:request_id) { "_abc-123" }
  let(:org_slug) { "some-university" }

  describe "create and claim" do
    it "round trips the transaction" do
      token = described_class.create(request_id:, org_slug:)
      expect(token).to be_present
      expect(described_class.claim(token)).to eq({org_slug:, request_id:})
    end

    it "only claims once" do
      token = described_class.create(request_id:, org_slug:)
      described_class.claim(token)
      expect(described_class.claim(token)).to be_nil
    end

    it "issues a distinct token per request" do
      tokens = Array.new(3) { described_class.create(request_id:, org_slug:) }
      expect(tokens.uniq.count).to eq 3
    end

    it "expires" do
      token = described_class.create(request_id:, org_slug:)
      ttl = RedisPool.conn { |r| r.ttl("saml_request:#{token}") }
      expect(ttl).to be_within(5).of(described_class::TTL.to_i)
    end
  end

  describe "claim" do
    it "is nil for a blank token" do
      expect(described_class.claim(nil)).to be_nil
      expect(described_class.claim("")).to be_nil
    end

    it "is nil for an unknown token" do
      expect(described_class.claim("not-a-real-token")).to be_nil
    end
  end
end
