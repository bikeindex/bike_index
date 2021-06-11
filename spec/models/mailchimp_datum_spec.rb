require 'rails_helper'

RSpec.describe MailchimpDatum, type: :model do
  describe "find_or_create_for" do
    before { Sidekiq::Worker.clear_all }

    context "user" do
      let(:user) { FactoryBot.create(:user, email: "test@stuff.com") }
      it "does not creates if not required" do
        mailchimp_datum = MailchimpDatum.find_or_create_for(user)
        expect(mailchimp_datum.audiences).to eq([])
        expect(mailchimp_datum.no_subscription_required?).to be_truthy
        expect(mailchimp_datum.id).to be_blank
        expect(UpdateMailchimpDatumWorker.jobs.count).to eq 0
      end
      context "feedback" do
        let!(:feedback) { FactoryBot.create(:feedback, user: user, kind: "lead_for_bike_shop") }
        it "creates and then finds for the user" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          expect(user.feedbacks.pluck(:id)).to eq([feedback.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(user)
          expect(mailchimp_datum.audiences).to eq(["lead_for_bike_shop"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])

          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
        end
      end
    end
  end
end
