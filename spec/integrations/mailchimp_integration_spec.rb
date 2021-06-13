require "rails_helper"

RSpec.describe MailchimpIntegration do
  let(:instance) { described_class.new }

  describe "get_lists" do
    let(:target) do
      [{name: "Individuals", id: "180a1141a4"},
        {name: "Organizations", id: "b675299293"}]
    end
    it "gets the lists" do
      VCR.use_cassette("mailchimp_integration-get_lists", match_requests_on: [:path]) do
        lists = instance.get_lists
        expect(lists.map { |l| l.slice("name", "id") }).to eq target.as_json
      end
    end
  end

  describe "member_update_hash" do
    let(:mailchimp_datum) { MailchimpDatum.create(email: "example@bikeindex.org") }
    let(:target) do
      {email: "example@bikeindex.org",
       full_name: nil,
       interests: [],
       merge_fields: {},
       status: "unsubscribed"}
    end
    it "is expected" do
      expect(instance.member_update_hash(mailchimp_datum, "organization")).to eq target
    end
  end

  describe "get_member" do
    let(:mailchimp_datum) { MailchimpDatum.create(email: "example@bikeindex.org") }
    it "gets mailchimp response" do
      expect(mailchimp_datum.id).to be_blank
      expect(mailchimp_datum.subscriber_hash).to eq "ae3dd3401b5ed77b0a23d85874d6113b"

      VCR.use_cassette("mailchimp_integration-get_member-example", match_requests_on: [:path]) do
        result = instance.get_member(mailchimp_datum, "individual")
        expect(result).to eq nil
      end
    end
  end
end
