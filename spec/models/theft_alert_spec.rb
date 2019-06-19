require "rails_helper"

RSpec.describe TheftAlert, type: :model do
  describe "#begin!" do
    context "given no facebook post url" do
      it "rejects the update, sets an error" do
        theft_alert = FactoryBot.create(:theft_alert)

        theft_alert.begin!(facebook_post_url: "")

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
        now = nil

        Timecop.freeze do
          now = Time.current
          theft_alert.begin!(facebook_post_url: "https://facebook.com")
        end

        expect(theft_alert.begin_at).to eq(now.beginning_of_day)
        expect(theft_alert.end_at).to eq(now.end_of_day + duration.days)
        expect(theft_alert.status).to eq("active")
      end
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
