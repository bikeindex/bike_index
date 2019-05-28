require "spec_helper"

describe Feedback do
  describe "create" do
    it "enqueues an email job" do
      expect do
        FactoryBot.create(:feedback)
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
    end

    it "enqueues an email job for delete requests" do
      expect do
        FactoryBot.create(:feedback, feedback_type: "bike_delete_request")
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
    end

    it "doesn't enqueue an email job for serial updates" do
      expect do
        FactoryBot.create(:feedback, feedback_type: "serial_update_request")
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end

    it "doesn't enqueue an email job for manufacturer updates" do
      expect do
        FactoryBot.create(:feedback, feedback_type: "manufacturer_update_request")
      end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
    end

    it "auto sets the body for a lead_type" do
      feedback = Feedback.create(additional: "small", feedback_type: "lead_for_school", email: "example@example.com", package_size: "small")
      expect(feedback.looks_like_spam?).to be_truthy
      expect(feedback.errors.full_messages).to_not be_present
      expect(feedback.errors.count).to eq 0
      expect(feedback.id).to be_present
      expect(feedback.feedback_hash).to eq(package_size: "small")
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
      it "returns nil" do
        expect(Feedback.new(feedback_type: "manufacturer_update_request").lead_type).to be_nil
      end
    end
    context "lead type feedback" do
      it "returns type" do
        expect(Feedback.new(feedback_type: "lead_for_school").lead_type).to eq "School"
      end
    end
  end
end
