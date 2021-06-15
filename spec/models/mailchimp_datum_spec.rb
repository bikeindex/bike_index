require "rails_helper"

RSpec.describe MailchimpDatum, type: :model do
  let(:organization) { FactoryBot.create(:organization, kind: organization_kind) }
  let(:organization_kind) { "bike_shop" }
  let(:empty_data) { {lists: [], tags: [], interests: []} }

  describe "find_or_create_for" do
    before { Sidekiq::Worker.clear_all }

    context "user" do
      let(:user) { FactoryBot.create(:user, email: "test@stuff.com") }
      it "does not creates if not required" do
        mailchimp_datum = MailchimpDatum.find_or_create_for(user)
        expect(mailchimp_datum.lists).to eq([])
        expect(mailchimp_datum.no_subscription_required?).to be_truthy
        expect(mailchimp_datum.id).to be_blank
        expect(mailchimp_datum.data).to eq empty_data.merge(tags: ["in_index"]).as_json
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
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to eq user.id
          expect(user.reload.mailchimp_datum&.id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])
          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)

          # Destroying the user updates mailchimp
          user.destroy
          expect {
            mailchimp_datum.reload.update(updated_at: Time.current)
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
           interests: ["school"]}
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
    context "empty" do
      let(:mailchimp_datum) { MailchimpDatum.new }
      it "is empty" do
        expect(mailchimp_datum.calculated_data.as_json).to eq empty_data.as_json
        # expect(mailchimp_datum.member_hash).to eq empty_member_hash
      end
    end
    context "with organization admin" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      let(:mailchimp_datum) { MailchimpDatum.create(user: user) }
      let(:target) { {lists: ["organization"], tags: %w[in_index], interests: %w[bike_shop]} }
      let(:target_merge_fields) do
        {
          organization_kind: "bike_shop",
          organization_name: organization.name.to_s,
          organization_url: organization.website,
          organization_country: nil,
          organization_city: nil,
          organization_state: nil,
          organization_signed_up_at: organization.created_at,
          bikes: 0,
          name: user.name,
          phone_number: user.phone,
          user_signed_up_at: user.created_at,
          added_to_mailchimp_at: nil
        }
      end
      it "is as expected" do
        expect(user.reload.memberships.first.organization_creator?).to be_truthy
        expect(mailchimp_datum.calculated_data.as_json).to eq target.as_json
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
          target_merge_fields.merge(organization_url: "http://test.com",
                                    organization_country: "US",
                                    organization_city: "Chicago",
                                    organization_state: "IL")
        end

        # Organizations
        # Add: pos_approved
        # Add paid - paid invoice associated
        # Add previously_paid tag

        # Individual
        # Most recent_donation_at
        # Number of donations

        it "responds with lightspeed" do
          expect(location.reload&.state&.abbreviation).to eq "IL"
          organization.update(website: "test.com")
          expect(user).to be_present
          organization.update(pos_kind: "lightspeed_pos")
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in_index lightspeed]).as_json
          expect(mailchimp_datum.merge_fields.as_json).to eq lightspeed_merge_fields.as_json
        end
      end
      context "ascend" do
        it "responds with lightspeed" do
          expect(user).to be_present
          organization.update(pos_kind: "ascend_pos")
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[ascend in_index]).as_json
        end
      end
      context "not creator of organization" do
        let!(:organization_creator) { FactoryBot.create(:organization_admin, organization: organization) }
        it "is as expected" do
          expect(organization_creator.reload.memberships.first.organization_creator?).to be_truthy
          expect(user.reload.memberships.first.organization_creator?).to be_falsey
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in_index not_organization_creator]).as_json
        end
      end
    end
  end
end
