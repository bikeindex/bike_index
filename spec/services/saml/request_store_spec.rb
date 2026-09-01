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
      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: nil, mode: "normal", expected_email: nil})
      expect(described_class.create(request_id:, org_slug:)).to_not eq token
    end
  end

  describe "return_to" do
    let(:token) { described_class.create(request_id:, org_slug:, return_to: "/bikes/new") }

    it "travels with the transaction, the callback having no session to read it from" do
      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: "/bikes/new", mode: "normal", expected_email: nil})
    end
  end

  describe "claim" do
    it "succeeds once, the token being single use" do
      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: nil, mode: "normal", expected_email: nil})
      expect(described_class.claim(token)).to be_nil
    end

    context "a token we never issued" do
      it "is nil rather than raising" do
        expect(described_class.claim(nil)).to be_nil
        expect(described_class.claim("")).to be_nil
        expect(described_class.claim("not-a-real-token")).to be_nil
      end
    end

    context "a payload create no longer writes" do
      it "is nil rather than raising, the same as a token we never issued" do
        RedisPool.conn { |r| r.set("saml_request:stale-format", "some-university\n_abc-123") }

        expect(described_class.claim("stale-format")).to be_nil
      end
    end
  end

  describe "mode" do
    it "round trips the test mode" do
      token = described_class.create(request_id:, org_slug:, mode: described_class::TEST_MODE)

      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: nil, mode: "test", expected_email: nil})
    end

    it "round trips the address the test form collected" do
      token = described_class.create(request_id:, org_slug:, mode: described_class::TEST_MODE,
        expected_email: "someone@example.edu")

      expect(described_class.claim(token)).to eq({org_slug:, request_id:, return_to: nil, mode: "test",
                                                  expected_email: "someone@example.edu"})
    end
  end
end
