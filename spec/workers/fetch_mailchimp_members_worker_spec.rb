require "rails_helper"

RSpec.describe FetchMailchimpMembersWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    context "organization" do
      let(:target_data) do
        {
          tags: ["In Bike Index"],
          interests: [],
          lists: ["organization"],
          mailchimp_interests: {organization: ["cbca7bf705"]},
          mailchimp_merge_fields: {"MMERGE5" => "Ike's Bikes"}
        }
      end
      let(:mailchimp_updated_at) { TimeParser.parse("2021-06-11T19:06:19+00:00") }
      it "creates the given number of mailchimp_datums" do
        expect(MailchimpDatum.count).to eq 0
        VCR.use_cassette("fetch_mailchimp_members_worker-success", match_requests_on: [:path]) do
          instance.perform("organization", 0, 1, false)
        end
        expect(MailchimpDatum.count).to eq 1
        mailchimp_datum = MailchimpDatum.last
        expect(mailchimp_datum.on_mailchimp?).to be_truthy
        expect(mailchimp_datum.lists).to eq(%w[organization])
        expect(mailchimp_datum.email).to eq "example@boardermail.com"
        expect(mailchimp_datum.user_id).to be_blank
        expect(mailchimp_datum.status).to eq "subscribed"
        expect(mailchimp_datum.data).to eq target_data.as_json
        expect(mailchimp_datum.mailchimp_updated_at).to be_within(1).of mailchimp_updated_at
      end
    end
    context "individual" do
      let(:target_data) do
        {
          tags: ["2020", "in-bike-index"],
          interests: [],
          lists: %w[individual organization],
          mailchimp_interests: {individual: ["938bcefe9e"]},
          mailchimp_merge_fields: {"NAME" => "Seth Herr"}
        }
      end
      let(:user) { FactoryBot.create(:user, email: "seth@bikeindex.org") }
      let!(:mailchimp_datum) { MailchimpDatum.create(user: user, mailchimp_updated_at: Time.current - 1.year, data: {lists: ["organization"]}) }
      let(:mailchimp_updated_at) { TimeParser.parse("2021-06-11T20:11:41+00:00") }
      it "does not duplicate user" do
        expect(MailchimpDatum.count).to eq 1
        expect(mailchimp_datum.reload.lists).to eq(["organization"])
        Sidekiq::Worker.clear_all
        VCR.use_cassette("fetch_mailchimp_members_worker-individual", match_requests_on: [:path]) do
          instance.perform("individual", 0, 1, true)
        end
        expect(MailchimpDatum.count).to eq 1
        expect(mailchimp_datum.reload.lists).to eq(%w[individual organization])
        expect(mailchimp_datum.email).to eq "seth@bikeindex.org"
        expect(mailchimp_datum.user_id).to eq user.id
        expect(mailchimp_datum.status).to eq "subscribed"
        expect(mailchimp_datum.data).to eq target_data.as_json
        expect(mailchimp_datum.mailchimp_updated_at).to be_within(1).of mailchimp_updated_at

        # Because we're enqueue_all_pages
        expect(described_class.jobs.count).to be > 1000
      end
    end
  end
end
