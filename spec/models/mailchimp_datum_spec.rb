require "rails_helper"

RSpec.describe MailchimpDatum, type: :model do
  let(:organization) { FactoryBot.create(:organization, kind: organization_kind) }
  let(:organization_kind) { "bike_shop" }
  let(:empty_data) { {lists: [], tags: [], interests: [], merge_fields: nil} }

  describe "find_or_create_for" do
    before { Sidekiq::Worker.clear_all }

    context "user" do
      let(:user) { FactoryBot.create(:user, email: "test@stuff.com") }
      it "does not creates if not required" do
        mailchimp_datum = MailchimpDatum.find_or_create_for(user)
        expect(mailchimp_datum.lists).to eq([])
        expect(mailchimp_datum.no_subscription_required?).to be_truthy
        expect(mailchimp_datum.id).to be_blank
        expect(mailchimp_datum.data).to eq empty_data.merge(tags: ["in-bike-index"]).as_json
        expect(mailchimp_datum.subscriber_hash).to eq "4108acb6069e48c2eec39cb7ecc002fe"
        expect(UpdateMailchimpDatumWorker.jobs.count).to eq 0
      end
      context "organization admin" do
        let!(:membership) { FactoryBot.create(:membership_claimed, role: "admin", user: user, organization: organization) }
        it "creates and then finds for the user" do
          expect(user.organizations.pluck(:id)).to eq([organization.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(user)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.on_mailchimp?).to be_falsey
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to eq user.id
          expect(user.reload.mailchimp_datum&.id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])
          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
          expect(mailchimp_datum.should_update?).to be_truthy

          # Destroying the user updates mailchimp
          user.destroy
          expect {
            mailchimp_datum.reload
            mailchimp_datum.update(updated_at: Time.current)
          }.to change(UpdateMailchimpDatumWorker.jobs, :count).by 1
          mailchimp_datum.reload
          expect(mailchimp_datum.user_deleted?).to be_truthy
          expect(mailchimp_datum.status).to eq "unsubscribed"
          expect(mailchimp_datum.user_id).to be_present
        end
      end
      context "organization member" do
        let!(:membership) { FactoryBot.create(:membership_claimed, role: "member", user: user, organization: organization) }
        it "does not create" do
          expect(user.organizations.pluck(:id)).to eq([organization.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(user)
          expect(mailchimp_datum.lists).to eq([])
          expect(mailchimp_datum.status).to eq "no_subscription_required"
          expect(mailchimp_datum.id).to be_blank
          expect(UpdateMailchimpDatumWorker.jobs.count).to eq 0
        end
      end
      context "with feedback" do
        let!(:feedback) { FactoryBot.create(:feedback, user: user, kind: "lead_for_bike_shop") }
        it "creates and then finds for the user" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          expect(user.feedbacks.pluck(:id)).to eq([feedback.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(user)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to eq user.id
          expect(mailchimp_datum.feedbacks.pluck(:id)).to eq([feedback.id])
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])

          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)

          # And test that creating a membership doesn't result in update mailchimp datum
          FactoryBot.create(:membership_claimed, user: user, organization: organization)
          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
        end
        it "also creates if passed the feedback" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          expect(user.feedbacks.pluck(:id)).to eq([feedback.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(feedback)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to eq user.id
          expect(mailchimp_datum.feedbacks.pluck(:id)).to eq([feedback.id])
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])

          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
          # Thow this test in here too
          expect(MailchimpDatum.list("organization").pluck(:id)).to eq([mailchimp_datum.id])
          expect(MailchimpDatum.list("individual").pluck(:id)).to eq([])
          expect(MailchimpDatum.list("stuff").pluck(:id)).to eq([])
        end
      end
    end
    context "feedback" do
      let(:feedback) { FactoryBot.create(:feedback, kind: "message") }
      it "does not create" do
        mailchimp_datum = MailchimpDatum.find_or_create_for(feedback)
        expect(mailchimp_datum.lists).to eq([])
        expect(mailchimp_datum.no_subscription_required?).to be_truthy
        expect(mailchimp_datum.id).to be_blank
        expect(UpdateMailchimpDatumWorker.jobs.count).to eq 0
      end
      context "lead_for_school" do
        let!(:feedback) { FactoryBot.create(:feedback, kind: "lead_for_school") }
        let(:target) do
          {lists: ["organization"],
           tags: [],
           interests: ["school"],
           merge_fields: nil}
        end
        it "creates" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          mailchimp_datum = MailchimpDatum.find_or_create_for(feedback)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to be_blank
          expect(mailchimp_datum.feedbacks.pluck(:id)).to eq([feedback.id])
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
          expect(mailchimp_datum.data).to eq target.as_json
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])

          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
        end
      end
    end
  end

  describe "calculated_lists" do
    it "is empty" do
      expect(MailchimpDatum.new.send("calculated_lists")).to eq([])
    end
  end

  describe "calculated_data" do
    let(:mailchimp_datum) { MailchimpDatum.create(user: user) }
    context "empty" do
      let(:user) { User.new }
      it "is empty" do
        expect(mailchimp_datum.calculated_data.as_json).to eq empty_data.merge("tags" => ["in-bike-index"]).as_json
      end
    end
    context "with organization admin" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      let(:target) { {lists: ["organization"], tags: %w[in-bike-index], interests: %w[bike_shop], merge_fields: nil} }
      let(:target_merge_fields) do
        {
          "organization-name" => organization.name.to_s,
          "organization-signed-up-at" => organization.created_at.to_date&.to_s,
          "bikes" => 0,
          "name" => user.name,
          "phone-number" => user.phone,
          "signed-up-at" => user.created_at.to_date&.to_s,
          "added-to-mailchimp-at" => nil,
          "most-recent-donation-at" => nil,
          "number-of-donations" => 0,
          "recovered-bike-at" => nil
        }
      end
      it "is as expected" do
        expect(user.reload.memberships.first.organization_creator?).to be_truthy
        expect(mailchimp_datum.calculated_data.as_json).to eq target.as_json
        expect(mailchimp_datum.merge_fields.as_json).to eq target_merge_fields.as_json
      end
      context "not creator of organization" do
        let(:organization_kind) { "software" }
        it "is as expected" do
          expect(user).to be_present
          organization.update(pos_kind: "does_not_need_pos")
          expect(organization.reload.pos_kind).to eq "does_not_need_pos"
          # Doesn't include does_not_need_pos tag
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(interests: ["software"]).as_json
          expect(mailchimp_datum.merge_fields.as_json).to eq target_merge_fields.as_json
        end
      end
      context "lightspeed" do
        let!(:location) { FactoryBot.create(:location_chicago, organization: organization) }
        let(:lightspeed_merge_fields) do
          target_merge_fields.merge("organization-country" => "US",
                                    "organization-city" => "Chicago",
                                    "organization-state" => "IL")
        end

        it "responds with lightspeed" do
          expect(location.reload&.state&.abbreviation).to eq "IL"
          organization.update(website: "test.com")
          expect(user).to be_present
          organization.update(pos_kind: "lightspeed_pos")
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in-bike-index lightspeed pos-approved]).as_json
          expect(mailchimp_datum.merge_fields.as_json).to eq target_merge_fields.as_json
        end
      end
      context "ascend" do
        let!(:invoice) { FactoryBot.create(:invoice, organization: organization) }
        it "responds with lightspeed" do
          expect(user).to be_present
          organization.update(pos_kind: "ascend_pos")
          expect(organization.reload.paid?).to be_falsey
          expect(organization.invoices.count).to eq 1
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[ascend in-bike-index pos-approved]).as_json
        end
      end
      context "not creator of organization" do
        let!(:organization_creator) { FactoryBot.create(:organization_admin, organization: organization) }
        it "is as expected" do
          expect(organization_creator.reload.memberships.first.organization_creator?).to be_truthy
          expect(user.reload.memberships.first.organization_creator?).to be_falsey
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in-bike-index not-org-creator]).as_json
        end
      end
      context "paid organization" do
        let!(:invoice) { FactoryBot.create(:invoice_paid, organization: organization) }
        it "returns paid" do
          organization.update(updated_at: Time.current)
          expect(organization.reload.paid?).to be_truthy
          expect(organization.paid_previously?).to be_falsey
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in-bike-index paid]).as_json
        end
      end
      context "previously paid" do
        let!(:invoice) { FactoryBot.create(:invoice_paid, organization: organization, start_at: Time.current - 2.years) }
        it "returns paid_previously" do
          organization.reload
          expect(organization.paid?).to be_falsey
          expect(organization.paid_previously?).to be_truthy
          expect(invoice.reload.was_active?).to be_truthy
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in-bike-index paid-previously]).as_json
        end
      end
    end
    context "individual" do
      let(:user) { FactoryBot.create(:user) }
      let(:payment_time) { Time.at(1621876049) }
      let(:payment) { FactoryBot.create(:payment, user: user, kind: "donation", created_at: payment_time) }
      let(:target) { {lists: ["individual"], tags: %w[in-bike-index], interests: %w[donors], merge_fields: nil} }
      let(:target_merge_fields) do
        {
          "organization-name" => nil,
          "organization-signed-up-at" => nil,
          "bikes" => 0,
          "name" => user.name,
          "phone-number" => user.phone,
          "signed-up-at" => user.created_at.to_date&.to_s,
          "added-to-mailchimp-at" => nil,
          "most-recent-donation-at" => payment_time.to_date.to_s,
          "number-of-donations" => 1,
          "recovered-bike-at" => nil
        }
      end
      it "is as expected" do
        payment.reload
        expect(mailchimp_datum.calculated_data.as_json).to eq target.as_json
        expect(mailchimp_datum.merge_fields.as_json).to eq target_merge_fields.as_json
      end
      context "recovered_bike_owner" do
        let(:bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed, user: user) }
        let(:recovery_time) { Time.at(1592760319) }
        let(:target) { {lists: ["individual"], tags: %w[in-bike-index], interests: %w[recovered-bike-owners], merge_fields: nil} }
        before { bike.fetch_current_stolen_record.add_recovery_information(recovered_at: recovery_time.to_s) }
        let(:target_merge_fields_recovered) do
          target_merge_fields.merge("most-recent-donation-at" => nil, "bikes" => 1,
                                    "number-of-donations" => 0, "recovered-bike-at" => recovery_time.to_date.to_s)
        end
        it "is recovered" do
          expect(bike.reload.stolen_recovery?).to be_truthy
          expect(mailchimp_datum.stolen_records_recovered.pluck(:bike_id)).to eq([bike.id])
          expect(mailchimp_datum.calculated_data.as_json).to eq target.as_json
          expect(mailchimp_datum.merge_fields.as_json).to eq target_merge_fields_recovered.as_json
        end
        context "both" do
          let(:target) { {lists: ["individual"], tags: %w[in-bike-index], interests: %w[donors recovered-bike-owners], merge_fields: nil} }
          let(:target_merge_fields_both) { target_merge_fields.merge("recovered-bike-at" => recovery_time.to_date.to_s, "bikes" => 1) }
          it "is both" do
            payment.reload
            expect(bike.reload.stolen_recovery?).to be_truthy
            expect(mailchimp_datum.stolen_records_recovered.pluck(:bike_id)).to eq([bike.id])
            expect(mailchimp_datum.calculated_data.as_json).to eq target.as_json
            expect(mailchimp_datum.merge_fields.as_json).to eq target_merge_fields_both.as_json
          end
        end
      end
    end
  end

  describe "mailchimp_organization_membership" do
    let(:user) { FactoryBot.create(:organization_admin) }
    let(:organization1) { user.organizations.first }
    let(:membership2) { FactoryBot.create(:membership_claimed, user: user, role: "admin") }
    let(:organization2) { membership2.organization }
    let!(:mailchimp_datum) { MailchimpDatum.find_or_create_for(user) }
    it "uses the existing organization" do
      expect(mailchimp_datum).to be_valid
      expect(mailchimp_datum.mailchimp_organization&.id).to eq organization1.id
      mailchimp_datum.data["merge_fields"] = mailchimp_datum.merge_fields
      mailchimp_datum.update(updated_at: Time.current)
      expect(membership2).to be_valid
      user.reload
      id = mailchimp_datum.id
      mailchimp_datum = MailchimpDatum.find(id) # Unmemoize
      expect(mailchimp_datum.mailchimp_organization&.id).to eq organization1.id
    end
  end
end
