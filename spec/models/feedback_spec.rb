require "rails_helper"

RSpec.describe Feedback, type: :model do
  describe "bike" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:feedback) { FactoryBot.create(:feedback_serial_update_request, bike: bike) }
    it "finds it, returns bike" do
      expect(Feedback.bike.pluck(:id)).to eq([feedback.id])
      expect(Feedback.bike(bike).pluck(:id)).to eq([feedback.id])
      expect(Feedback.bike(bike.id).pluck(:id)).to eq([feedback.id])
      expect(feedback.bike).to eq bike
    end
  end
  describe "create" do
    it "enqueues an email job" do
      expect {
        FactoryBot.create(:feedback)
      }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
    end

    it "doesn't send email" do
      expect {
        FactoryBot.create(:feedback, feedback_type: "bike_delete_request")
      }.to_not change(EmailFeedbackNotificationWorker.jobs, :size)
    end

    it "doesn't enqueue an email job for serial updates" do
      expect {
        FactoryBot.create(:feedback, feedback_type: "serial_update_request")
      }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end

    it "doesn't enqueue an email job for manufacturer updates" do
      expect {
        FactoryBot.create(:feedback, feedback_type: "manufacturer_update_request")
      }.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end

    it "auto sets the body for a lead_type" do
      feedback = Feedback.create(additional: "small", feedback_type: "lead_for_school", email: "example@example.com", package_size: "small")
      expect(feedback.looks_like_spam?).to be_truthy
      expect(feedback.errors.full_messages).to_not be_present
      expect(feedback.errors.count).to eq 0
      expect(feedback.id).to be_present
      expect(feedback.feedback_hash).to eq("package_size" => "small")
      expect(feedback.kind).to eq "lead_for_school"
      expect(feedback.humanized_kind).to eq "School lead"
    end
  end

  describe "looks_like_spam?" do
    let(:feedback) { FactoryBot.build(:feedback) }
    it "is false" do
      expect(feedback.looks_like_spam?).to be_falsey
      feedback.save
      expect(feedback.looks_like_spam?).to be_falsey
    end
    context "with no user" do
      let(:feedback) { Feedback.new(feedback_type: "comment", email: "stuff@stuff.com", additional: "DDDD") }
      it "is true" do
        expect(feedback.looks_like_spam?).to be_truthy
      end
    end
    context "with user" do
      let(:user) { User.new }
      let(:feedback) { Feedback.new(feedback_type: "comment", user: user, additional: "DDDD") }
      it "is true" do
        expect(feedback.looks_like_spam?).to be_falsey
      end
    end
  end

  describe "lead_type" do
    context "non-lead feedback" do
      let(:feedback) { Feedback.new(feedback_type: "manufacturer_update_request") }
      it "returns nil" do
        feedback.set_calculated_attributes
        expect(feedback.lead_type).to be_nil
        expect(feedback.kind).to eq "manufacturer_update_request"
      end
    end
    context "lead type feedback" do
      it "returns type" do
        expect(Feedback.new(feedback_type: "lead_for_school").lead_type).to eq "School"
      end
    end
  end
  describe "delete bike" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:feedback) { FactoryBot.build(:feedback_bike_delete_request, bike: bike) }
    it "deletes the bike" do
      expect(bike.paranoia_destroyed?).to be_falsey
      feedback.save
      bike.reload
      expect(bike.deleted_at).to be_present
      expect(bike.paranoia_destroyed?).to be_truthy
    end
    context "bike is impounded" do
      let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
      it "marks the impound_record removed_from_bike_index" do
        expect(impound_record.active?).to be_truthy
        expect(impound_record.impound_record_updates.count).to eq 0
        expect(bike.paranoia_destroyed?).to be_falsey
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          feedback.update(user_id: FactoryBot.create(:user).id) # ImpoundRecordUpdate requires a user_id
        end
        bike.reload
        impound_record.reload
        expect(impound_record.removed_from_bike_index?).to be_truthy
        expect(impound_record.impound_record_updates.count).to eq 1
        impound_record_update = impound_record.impound_record_updates.last
        expect(impound_record_update.user).to eq feedback.user
        expect(impound_record_update.kind).to eq "removed_from_bike_index"
        expect(bike.deleted_at).to be_present
        expect(bike.paranoia_destroyed?).to be_truthy
      end
    end
  end
end
