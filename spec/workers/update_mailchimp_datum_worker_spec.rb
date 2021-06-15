require "rails_helper"

RSpec.describe UpdateMailchimpDatumWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    context "organization creator, create user" do
      let(:user) { FactoryBot.create(:user, email: "seth@bikeindex.org", name: "Seth Herr") }
      let(:organization) { FactoryBot.create(:organization, kind: "school", name: "Hogwarts") }
      let!(:membership) { FactoryBot.create(:membership_claimed, organization: organization, user: user, role: "admin") }
      let!(:invoice) { FactoryBot.create(:invoice_paid, organization: organization) }
      let(:mailchimp_datum) { MailchimpDatum.find_or_create_for(user) }
      before do
        MailchimpValue.create(kind: "interest", slug: "school", mailchimp_id: "c5bbab099c", list: "organization")
        MailchimpValue.create(kind: "merge_field", slug: "name", mailchimp_id: "NAME", list: "organization")
        MailchimpValue.create(kind: "merge_field", slug: "organization-name", mailchimp_id: "O_NAME", list: "organization")
        MailchimpValue.create(kind: "merge_field", slug: "organization-sign-up", mailchimp_id: "O_AT", list: "organization")
        # MailchimpValue.create(kind: "merge_field", slug: "address", mailchimp_id: "ADDRESS", list: "organization")
        MailchimpValue.create(kind: "tag", slug: "in-bike-index", mailchimp_id: "87306", list: "organization")
      end
      let(:target_body) do
        {email_address: "seth@bikeindex.org",
         full_name: "Seth Herr",
         interests: {"c5bbab099c" => true},
         merge_fields: target_merge_fields,
         status_if_new: "subscribed"}
      end
      let(:target_merge_fields) { {"NAME" => "Seth Herr", "O_NAME" => "Hogwarts", "O_AT" => organization.created_at} }
      it "creates the given number of mailchimp_datums" do
        expect(mailchimp_datum).to be_valid
        mailchimp_datum.reload
        expect(MailchimpDatum.count).to eq 1
        expect(mailchimp_datum.reload.lists).to eq(["organization"])
        expect(mailchimp_datum.on_mailchimp?).to be_falsey
        expect(mailchimp_datum.mailchimp_interests("organization")).to eq(target_body[:interests])
        expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq target_merge_fields
        expect(MailchimpIntegration.new.member_update_hash(mailchimp_datum, "organization")).to eq target_body

        VCR.use_cassette("update_mailchimp_datum_worker-organization-create", match_requests_on: [:path]) do
          instance.perform(mailchimp_datum.id)
        end
        expect(MailchimpDatum.count).to eq 1
        expect(mailchimp_datum.reload.on_mailchimp?).to be_truthy
        expect(mailchimp_datum.lists).to eq(["organization"])
        expect(mailchimp_datum.interests).to eq(["school"])
        expect(mailchimp_datum.mailchimp_interests("organization")).to eq(target_body[:interests])
        expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq target_merge_fields
        expect(MailchimpIntegration.new.member_update_hash(mailchimp_datum, "organization")).to eq target_body
        pp mailchimp_datum
      end
    end
  end
end
