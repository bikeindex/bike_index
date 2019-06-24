require "rails_helper"

RSpec.describe TheftAlert, type: :model do
  describe "factory" do
    let(:theft_alert) { FactoryBot.build(:theft_alert) }
    it "is valid" do
      expect(theft_alert.save).to be_truthy
    end
    context "begun" do
      let(:theft_alert) { FactoryBot.build(:theft_alert_begun) }
      it "is valid" do
        expect(theft_alert.save).to be_truthy
      end
    end
    context "paid" do
      let(:theft_alert) { FactoryBot.build(:theft_alert_paid) }
      it "is valid" do
        expect(theft_alert.save).to be_truthy
        expect(theft_alert.payment).to be_present
      end
    end
  end

  describe "#begin!" do
    context "given no facebook post url" do
      it "rejects the update, sets an error" do
        theft_alert = FactoryBot.create(:theft_alert)

        theft_alert.begin!(facebook_post_url: "", notes: "")

        expect(theft_alert.reload.status).to eq("pending")
        expect(theft_alert.begin_at).to eq(nil)
        expect(theft_alert.end_at).to eq(nil)
        expect(theft_alert.errors.to_a).to eq(["Facebook post url must be a valid url"])
      end
    end

    context "given a facebook post url" do
      it "sets begin and end times, flips the status" do
        theft_alert = FactoryBot.create(:theft_alert_paid)
        duration = theft_alert.theft_alert_plan.duration_days
        now = Time.current

        theft_alert.begin!(facebook_post_url: "https://facebook.com", notes: "")

        expect(theft_alert.begin_at).to be_within(5.seconds).of(now)
        expect(theft_alert.end_at).to eq(now.end_of_day + duration.days)
        expect(theft_alert.status).to eq("active")
      end
    end
  end

  describe "#update_details!" do
    it "updates permitted fields, leaving status, alert timestamps unchanged" do
      theft_alert = FactoryBot.create(:theft_alert_begun)

      theft_alert.update_details!(facebook_post_url: "a url", notes: "a note")

      expect(theft_alert.errors.to_a).to be_empty
      expect(theft_alert.facebook_post_url).to eq("a url")
      expect(theft_alert.notes).to eq("a note")
      expect(theft_alert.status).to eq("active")
    end
  end

  describe "#end!" do
    it "sets the alert status, without changing other state values" do
      theft_alert = FactoryBot.create(:theft_alert_begun)
      begin_at = theft_alert.begin_at
      end_at = theft_alert.end_at
      fb_url = theft_alert.facebook_post_url

      theft_alert.end!

      expect(theft_alert.status).to eq("inactive")
      expect(theft_alert.begin_at).to eq(begin_at)
      expect(theft_alert.end_at).to eq(end_at)
      expect(theft_alert.facebook_post_url).to eq(fb_url)
    end
  end

  describe "#reset!" do
    it "resets the alert state to pending" do
      theft_alert = FactoryBot.create(:theft_alert_ended)
      theft_alert.reset!

      expect(theft_alert.status).to eq("pending")
      expect(theft_alert.begin_at).to eq(nil)
      expect(theft_alert.end_at).to eq(nil)
      expect(theft_alert.facebook_post_url).to eq("")
    end
  end
end
