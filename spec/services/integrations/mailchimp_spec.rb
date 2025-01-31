require "rails_helper"

RSpec.describe Integrations::Mailchimp do
  let(:instance) { described_class.new }

  describe "get_lists" do
    let(:target) do
      [{name: "Individuals", id: "180a1141a4"},
        {name: "Organizations", id: "b675299293"}]
    end
    it "gets the lists" do
      VCR.use_cassette("mailchimp_integration-get_lists", match_requests_on: [:path]) do
        expect(instance.get_lists).to match_array(target.as_json)
      end
    end
  end

  describe "member_update_hash" do
    let(:mailchimp_datum) { MailchimpDatum.create(email: "example@bikeindex.org") }
    let(:target) do
      {email_address: "example@bikeindex.org",
       full_name: nil,
       interests: {},
       merge_fields: {},
       status_if_new: "unsubscribed"}
    end
    it "is expected" do
      expect(instance.member_update_hash(mailchimp_datum, "organization").as_json).to eq target.as_json
    end
  end

  describe "get_member" do
    context "no existing member" do
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

  describe "get_interest_categories" do
    let(:target) { [{list_id: "180a1141a4", id: "bec514f886", title: "Bike Index user types", display_order: 0, type: "hidden"}] }
    it "gets interest categories" do
      VCR.use_cassette("mailchimp_integration-get_interest_categories", match_requests_on: [:path]) do
        expect(instance.get_interest_categories("individual")).to eq target.as_json
      end
    end
  end

  describe "update_member_tags" do
    let(:mailchimp_datum) { MailchimpDatum.new(data: {tags: %w[in_bike_index paid_previously]}, email: "seth@bikeindex.org") }
    before do
      MailchimpValue.create(kind: "tag", name: "Paid", mailchimp_id: "1881982", list: "organization")
      MailchimpValue.create(kind: "tag", name: "Paid previously", mailchimp_id: "1889778", list: "organization")
      MailchimpValue.create(kind: "tag", name: "In Bike Index", mailchimp_id: "87306", list: "organization")
      MailchimpValue.create(kind: "tag", name: "In Bike Index", mailchimp_id: "1889682", list: "individual")
    end
    let(:target_tags_hash) { [{name: "In Bike Index", status: "active"}, {name: "Paid", status: "inactive"}, {name: "Paid previously", status: "active"}] }
    it "updates with tags" do
      MailchimpValue.create(kind: "tag", name: "Paid previously", mailchimp_id: "1881982", list: "organization")
      expect(mailchimp_datum.mailchimp_tags("organization")).to match_array target_tags_hash
      VCR.use_cassette("mailchimp_integration-update_member_tags", match_requests_on: [:path]) do
        expect(instance.update_member_tags(mailchimp_datum, "organization")).to be_truthy # WTF mailchimp, send back the tags or something
      end
    end
  end
end
