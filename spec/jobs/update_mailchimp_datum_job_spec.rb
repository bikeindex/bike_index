require "rails_helper"

RSpec.describe UpdateMailchimpDatumJob, type: :job do
  let(:instance) { described_class.new }
  before { stub_const("UpdateMailchimpDatumJob::UPDATE_MAILCHIMP", true) }
  describe "perform" do
    context "organization" do
      let(:target_body) do
        {email_address: email_address,
         full_name: "Seth Herr",
         interests: {"c5bbab099c" => true},
         merge_fields: target_merge_fields,
         status_if_new: "subscribed"}
      end
      let(:email_address) { "seth@bikeindex.org" }
      let(:user) { FactoryBot.create(:user, email: email_address, name: "Seth Herr") }
      let(:organization_created_at) { Time.at(1552072143) }
      let(:target_merge_fields) { {"NAME" => "Seth Herr", "O_NAME" => "Hogwarts", "O_AT" => organization_created_at.to_date.to_s} }
      let(:organization) { FactoryBot.create(:organization, kind: "school", name: "Hogwarts", created_at: organization_created_at) }
      let(:organization_role) { FactoryBot.create(:organization_role_claimed, organization: organization, user: user, role: "admin") }
      let(:mailchimp_datum) { MailchimpDatum.find_or_create_for(user) }

      context "organization creator, create user" do
        let!(:invoice) { FactoryBot.create(:invoice_with_payment, organization: organization) }
        before do
          MailchimpValue.create(kind: "interest", name: "school", mailchimp_id: "c5bbab099c", list: "organization")
          MailchimpValue.create(kind: "merge_field", name: "name", mailchimp_id: "NAME", list: "organization")
          MailchimpValue.create(kind: "merge_field", name: "organization_name", mailchimp_id: "O_NAME", list: "organization")
          MailchimpValue.create(kind: "merge_field", name: "organization_signed_up_at", mailchimp_id: "O_AT", list: "organization")
          MailchimpValue.create(kind: "tag", name: "In Bike Index", mailchimp_id: "87306", list: "organization")
          MailchimpValue.create(kind: "tag", name: "paid", mailchimp_id: "1881982", list: "organization")
          MailchimpValue.create(kind: "tag", name: "Not org creator", mailchimp_id: "1882022", list: "organization")
        end
        let(:target_tags) { %w[in_bike_index paid] }
        it "updates mailchimp_datum" do
          expect(organization_role.organization_creator?).to be_truthy
          organization.update(updated_at: Time.current)
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(mailchimp_datum.mailchimp_organization&.paid_money?).to be_truthy
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.lists).to eq(["organization"])
          expect(mailchimp_datum.on_mailchimp?).to be_falsey
          expect(mailchimp_datum.should_update?).to be_truthy
          expect(mailchimp_datum.mailchimp_interests("organization")).to eq(target_body[:interests])
          expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq target_merge_fields
          expect(Integrations::Mailchimp.new.member_update_hash(mailchimp_datum, "organization")).to eq target_body
          expect(mailchimp_datum.tags).to match_array target_tags

          VCR.use_cassette("update_mailchimp_datum_worker-organization-create", match_requests_on: [:method]) do
            Sidekiq::Job.clear_all
            instance.perform(mailchimp_datum.id)
            expect(described_class.jobs.count).to eq 0
          end
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.on_mailchimp?).to be_truthy
          expect(mailchimp_datum.lists).to eq(%w[organization])
          expect(mailchimp_datum.interests).to eq(%w[school])
          expect(mailchimp_datum.mailchimp_interests("organization")).to eq(target_body[:interests])
          expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq target_merge_fields
          expect(Integrations::Mailchimp.new.member_update_hash(mailchimp_datum, "organization")).to eq target_body
          expect(mailchimp_datum.tags).to match_array(["in_bike_index", "not_org_creator", "paid"])
        end
      end
      context "not creator, update user" do
        before do
          MailchimpValue.create(kind: "merge_field", slug: "organization-city", mailchimp_id: "CITY", list: "organization")
          MailchimpValue.create(kind: "merge_field", slug: "organization-state", mailchimp_id: "STATE", list: "organization")
          MailchimpValue.create(kind: "merge_field", slug: "organization-country", mailchimp_id: "COUNTRY", list: "organization")
          MailchimpValue.create(kind: "tag", slug: "Not org creator", mailchimp_id: "1882022", list: "organization")
          MailchimpValue.create(kind: "tag", slug: "Weird new tag", mailchimp_id: "1892850", list: "individual")
        end
        let!(:location) { FactoryBot.create(:location, :with_address_record, address_in: :los_angeles, organization: organization) }
        let(:merge_address_fields) { {"O_CITY" => "Los Angeles", "O_STATE" => "CA", "O_COUNTRY" => "US"} }
        let(:target_tags) { ["In Bike Index", "in_bike_index", "weird other tag"] }
        let!(:payment) { FactoryBot.create(:payment, user: user, kind: "donation") }
        let(:target_merge_fields) do
          {"NAME" => "Seth Herr",
           "name" => "Seth Herr",
           "BIKES" => 9,
           "PHONE" => "xxxxxxx",
           "bikes" => 0,
           "RECOVE_AT" => "2015-08-05",
           "SIGN_UP_AT" => "2013-07-14",
           "signed_up_at" => "2021-06-22",
           "organization_name" => "Hogwarts",
           "number_of_donations" => 1,
           "most_recent_donation_at" => "2021-06-22",
           "organization_signed_up_at" => "2019-03-08"}
        end
        it "individual only" do
          mailchimp_datum.data["tags"] += ["weird other tag"]
          mailchimp_datum.update(updated_at: Time.current, mailchimp_updated_at: Time.current)
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(mailchimp_datum.should_update?).to be_falsey
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.lists).to eq(["individual"])
          expect(mailchimp_datum.on_mailchimp?).to be_truthy
          expect(mailchimp_datum.mailchimp_interests("individual")).to eq({})
          expect(mailchimp_datum.tags).to eq(["in_bike_index", "weird other tag"])
          VCR.use_cassette("update_mailchimp_datum_worker-individual-update", match_requests_on: [:method]) do
            instance.perform(mailchimp_datum.id, true) # Force update
          end
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.on_mailchimp?).to be_truthy
          expect(mailchimp_datum.lists).to eq(["individual"])
          expect(mailchimp_datum.interests).to eq(%w[938bcefe9e d14183c940 donors])
          expect(mailchimp_datum.should_update?).to be_falsey
          expect(mailchimp_datum.tags).to match_array target_tags

          expect(MailchimpDatum.list("organization").pluck(:id)).to eq([])
          expect(MailchimpDatum.list("individual").pluck(:id)).to eq([mailchimp_datum.id])
          # Make sure we aren't needlessly churning
          original_data = mailchimp_datum.data
          VCR.use_cassette("update_mailchimp_datum_worker-individual-update", match_requests_on: [:method]) do
            instance.perform(mailchimp_datum.id, true) # Force update
          end
          mailchimp_datum.reload
          expect(mailchimp_datum.data).to eq original_data
        end
        context "organization and individual" do
          let(:target_tags) { ["In Bike Index", "in_bike_index", "Not org creator", "not_org_creator", "Paid", "weird other tag"] }
          it "updates mailchimp_datum" do
            FactoryBot.create(:organization_role_claimed, organization: organization)
            organization.update(updated_at: Time.current)
            expect(organization.default_location&.id).to eq location.id
            expect(organization_role.reload.organization_creator?).to be_falsey
            expect(organization.reload.paid?).to be_falsey
            mailchimp_datum.data["tags"] += ["weird other tag"]
            mailchimp_datum.update(updated_at: Time.current, mailchimp_updated_at: Time.current)
            expect(mailchimp_datum).to be_valid
            mailchimp_datum.reload
            expect(mailchimp_datum.should_update?).to be_falsey
            expect(MailchimpDatum.count).to eq 1
            expect(mailchimp_datum.reload.lists).to eq(["organization"])
            expect(mailchimp_datum.on_mailchimp?).to be_truthy
            expect(mailchimp_datum.mailchimp_interests("organization")).to eq({})
            expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq merge_address_fields
            expect(mailchimp_datum.tags).to eq(["in_bike_index", "not_org_creator", "weird other tag"])
            VCR.use_cassette("update_mailchimp_datum_worker-organization-update", match_requests_on: [:method]) do
              instance.perform(mailchimp_datum.id, true) # Force update
            end
            expect(MailchimpDatum.count).to eq 1
            expect(mailchimp_datum.reload.on_mailchimp?).to be_truthy
            expect(mailchimp_datum.lists).to eq(["organization"])
            expect(mailchimp_datum.interests).to eq(%w[c5bbab099c donors school])
            expect(mailchimp_datum.mailchimp_merge_fields("organization")).to eq merge_address_fields
            expect(mailchimp_datum.should_update?).to be_falsey
            target = target_body.merge(interests: {}, merge_fields: merge_address_fields)
            expect(Integrations::Mailchimp.new.member_update_hash(mailchimp_datum, "organization")).to eq target
            expect(mailchimp_datum.tags).to match_array target_tags

            expect(MailchimpDatum.list("organization").pluck(:id)).to eq([mailchimp_datum.id])
            expect(MailchimpDatum.list("individual").pluck(:id)).to eq([])
            # Make sure we aren't needlessly churning
            original_data = mailchimp_datum.data
            VCR.use_cassette("update_mailchimp_datum_worker-organization-update", match_requests_on: [:method]) do
              instance.perform(mailchimp_datum.id, true) # Force update
            end
            mailchimp_datum.reload
            expect(mailchimp_datum.data).to eq original_data
          end
        end
      end
      context "mailchimp_datum archived" do
        let(:email_address) { "seth+archived@bikeindex.org" }
        it "updates mailchimp_datum" do
          expect(organization_role.organization_creator?).to be_truthy
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.status).to eq "subscribed"
          VCR.use_cassette("update_mailchimp_datum_worker-archived", match_requests_on: [:method]) do
            Sidekiq::Job.clear_all
            instance.perform(mailchimp_datum.id)
            expect(described_class.jobs.count).to eq 0

            user.destroy
            mailchimp_datum.update(updated_at: Time.current)
            expect(mailchimp_datum.reload.status).to eq "archived"
            expect(mailchimp_datum.should_update?).to be_truthy

            Sidekiq::Job.clear_all
            instance.perform(mailchimp_datum.id)
            expect(described_class.jobs.count).to eq 0
          end
          expect(mailchimp_datum.reload.status).to eq "archived"
          expect(mailchimp_datum.mailchimp_archived_at).to be > (Time.current - 1.minute)
          # Check that we don't enqueue again
          Sidekiq::Job.clear_all
          mailchimp_datum.update(mailchimp_updated_at: Time.current - 5.minutes)
          expect(mailchimp_datum.should_update?).to be_falsey
          expect(described_class.jobs.count).to eq 0
        end
      end
      context "archived on mailchimp" do
        let(:email_address) { "seth+archived@bikeindex.org" }
        it "marks as archived" do
          expect(organization_role.organization_creator?).to be_truthy
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.status).to eq "subscribed"
          VCR.use_cassette("update_mailchimp_datum_worker-archived_on_mailchimp", match_requests_on: [:method]) do
            instance.perform(mailchimp_datum.id, true)

            expect(mailchimp_datum.reload.status).to eq "archived"
            expect(mailchimp_datum.mailchimp_archived_at).to be < Time.current
          end
        end
      end
      context "unsubscribed" do
        let(:email_address) { "seth+unsubscribed@bikeindex.org" }
        it "updates mailchimp_datum" do
          expect(organization_role.organization_creator?).to be_truthy
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.status).to eq "subscribed"
          VCR.use_cassette("update_mailchimp_datum_worker-unsubscribed", match_requests_on: [:method]) do
            # Ran once, which subscribed the user, then deleted the cassette
            # Manually went in to mailchimp and set this user to be unsubscribed, and ran again
            Sidekiq::Job.clear_all
            instance.perform(mailchimp_datum.id)
            expect(described_class.jobs.count).to eq 0
            expect(mailchimp_datum.reload.status).to eq "unsubscribed"
          end
        end
      end
      context "suspiscious email" do
        let(:email_address) { "asdf891234123@sneakemail.com" }
        it "updates mailchimp_datum" do
          expect(organization_role.organization_creator?).to be_truthy
          expect(mailchimp_datum).to be_valid
          mailchimp_datum.reload
          expect(MailchimpDatum.count).to eq 1
          expect(mailchimp_datum.reload.status).to eq "subscribed"
          VCR.use_cassette("update_mailchimp_datum_worker-fail", match_requests_on: [:method]) do
            Sidekiq::Job.clear_all
            instance.perform(mailchimp_datum.id)
            expect(described_class.jobs.count).to eq 0
            expect(mailchimp_datum.reload.status).to eq "unsubscribed"
            expect(mailchimp_datum.data["mailchimp_error"]).to match(/fake or invalid/i)
          end
        end
      end
    end
  end
end
