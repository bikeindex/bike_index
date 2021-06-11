require 'rails_helper'

RSpec.describe MailchimpDatum, type: :model do
  let(:organization) { FactoryBot.create(:organization, kind: organization_kind) }
  let(:organization_kind) { "bike_shop"}

  describe "find_or_create_for" do
    before { Sidekiq::Worker.clear_all }

    context "user" do
      let(:user) { FactoryBot.create(:user, email: "test@stuff.com") }
      it "does not creates if not required" do
        mailchimp_datum = MailchimpDatum.find_or_create_for(user)
        expect(mailchimp_datum.lists).to eq([])
        expect(mailchimp_datum.no_subscription_required?).to be_truthy
        expect(mailchimp_datum.id).to be_blank
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
        let(:target) { { lists: ["organization"], tags: [], interests: {}}}
        it "creates" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          mailchimp_datum = MailchimpDatum.find_or_create_for(feedback)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to be_blank
          expect(mailchimp_datum.feedbacks.pluck(:id)).to eq([feedback.id])
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
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
end
