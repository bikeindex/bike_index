require "rails_helper"

RSpec.describe PromotedAlert, type: :model do
  describe "factory" do
    let(:promoted_alert) { FactoryBot.build(:promoted_alert) }
    it "is valid" do
      expect(promoted_alert.save).to be_truthy
      expect(PromotedAlert.paid.pluck(:id)).to eq([])
    end
    context "begun" do
      let(:promoted_alert) { FactoryBot.build(:promoted_alert_begun) }
      it "is valid" do
        expect(promoted_alert.save).to be_truthy
      end
    end
    context "paid" do
      let(:promoted_alert) { FactoryBot.build(:promoted_alert_paid) }
      it "is valid" do
        expect(promoted_alert.save).to be_truthy
        expect(promoted_alert.payment).to be_present
        expect(PromotedAlert.paid.pluck(:id)).to eq([promoted_alert.id])
        expect(promoted_alert.objective_campaign).to be_nil
        expect(promoted_alert.objective_adset).to be_nil
      end
    end
  end

  describe "recovered bike" do
    let(:stolen_record) { FactoryBot.create(:stolen_record_recovered) }
    let!(:stolen_record2) { FactoryBot.create(:stolen_record_recovered) }
    let!(:promoted_alert) { FactoryBot.create(:promoted_alert, stolen_record: stolen_record) }
    let!(:promoted_alert2) { FactoryBot.create(:promoted_alert) }
    it "returns the bike" do
      expect(promoted_alert.stolen_record).to eq stolen_record
      expect(promoted_alert.recovered?).to be_truthy
      expect(StolenRecord.unscoped.with_promoted_alerts.pluck(:id)).to match_array([stolen_record.id, promoted_alert2.stolen_record_id])
      expect(StolenRecord.recovered.with_promoted_alerts.pluck(:id)).to eq([stolen_record.id])
    end
  end

  describe "activateable?" do
    let(:promoted_alert) { FactoryBot.create(:promoted_alert, facebook_data: {no_notify: true}) }
    it "is false" do
      expect(promoted_alert.missing_location?).to be_truthy
      expect(promoted_alert.missing_photo?).to be_truthy
      expect(promoted_alert.stolen_record_approved?).to be_falsey
      expect(promoted_alert.paid?).to be_falsey
      expect(promoted_alert.activateable?).to be_falsey
      expect(promoted_alert.posted?).to be_falsey
      expect(promoted_alert.notify?).to be_falsey
    end
    context "is activateable" do
      let(:bike) { FactoryBot.create(:bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, bike: bike, approved: true) }
      let(:promoted_alert) { FactoryBot.create(:promoted_alert, :paid, stolen_record: stolen_record, facebook_data: {campaign_id: "xxxx"}) }
      it "is truthy" do
        expect(promoted_alert.missing_location?).to be_falsey
        expect(promoted_alert.missing_photo?).to be_falsey
        expect(promoted_alert.stolen_record_approved?).to be_truthy
        expect(promoted_alert.paid?).to be_truthy
        expect(promoted_alert.activateable?).to be_truthy
        expect(promoted_alert.posted?).to be_falsey
        expect(promoted_alert.failed_to_activate?).to be_falsey
        expect(PromotedAlert.activating.pluck(:id)).to eq([])
        expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([])
        # Also, test notify? in here too
        expect(promoted_alert.notify?).to be_truthy
        stolen_record.update(receive_notifications: false)
        promoted_alert.reload
        expect(promoted_alert.notify?).to be_falsey
      end
    end
  end

  describe "failed_to_activate?" do
    let(:promoted_alert) do
      FactoryBot.create(:promoted_alert, status: "pending", facebook_data: {activating_at:})
    end
    let(:activating_at) { (Time.current - 6.minutes).to_i }
    let(:start_at) { nil }
    it "is falsey" do
      expect(promoted_alert.reload.start_at).to be_nil
      expect(promoted_alert.failed_to_activate?).to be_truthy
      expect(PromotedAlert.activating.pluck(:id)).to eq([promoted_alert.id])
      expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([promoted_alert.id])

      promoted_alert.update(start_at: Time.current, end_at: Time.current + 1.day, status: "active")
      expect(promoted_alert.reload.start_at).to be_present
      expect(promoted_alert.failed_to_activate?).to be_falsey
      expect(PromotedAlert.activating.pluck(:id)).to eq([])
      expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([])
    end
    context "start_at more recently" do
      let(:activating_at) { (Time.current - 2.minutes).to_i }

      it "is falsey" do
        expect(promoted_alert.reload.failed_to_activate?).to be_falsey
        expect(PromotedAlert.activating.pluck(:id)).to eq([promoted_alert.id])
        expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([])
      end
    end
  end

  describe "facebook names" do
    let(:promoted_alert_plan) { PromotedAlertPlan.new(amount_cents_facebook: 1999) }
    let(:promoted_alert) { PromotedAlert.new(id: 12, promoted_alert_plan: promoted_alert_plan) }
    let(:facebook_name) { "Theft Alert 12 - $19.99" }
    it "returns the theft alert plan" do
      expect(promoted_alert.facebook_name("campaign")).to eq facebook_name
      expect(promoted_alert.facebook_name("adset")).to eq "#{facebook_name} - adset"
      expect(promoted_alert.facebook_name("ad")).to eq "#{facebook_name} - ad"
      expect(promoted_alert.amount_cents_facebook).to eq 1999
      # Setting facebook_data overrides
      promoted_alert.facebook_data = {"amount_cents" => 2909}
      expect(promoted_alert.amount_cents_facebook).to eq 2909
      expect(promoted_alert.facebook_name("ad")).to eq "Theft Alert 12 - $29.09 - ad"
    end
  end

  describe "facebook_updateable? and should_update_facebook?" do
    let(:promoted_alert) { FactoryBot.create(:promoted_alert, facebook_data: {}) }
    it "is falsey for no campaign_id" do
      expect(promoted_alert.reload.facebook_updateable?).to be_falsey
      expect(promoted_alert.should_update_facebook?).to be_falsey
      expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([])
    end
    context "campaign_id" do
      let(:end_at) { Time.current - 1.hour }
      let(:promoted_alert) { FactoryBot.create(:promoted_alert, facebook_data: {campaign_id: "cxcxc"}, start_at: Time.current - 1.week, end_at: end_at) }
      it "is truthy" do
        expect(promoted_alert.reload.facebook_updateable?).to be_truthy
        expect(promoted_alert.live?).to be_falsey
        expect(promoted_alert.should_update_facebook?).to be_truthy
        expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([promoted_alert.id])
        promoted_alert.update(facebook_updated_at: Time.current - 1.hour)
        expect(promoted_alert.reload.should_update_facebook?).to be_falsey
        expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([promoted_alert.id])
      end
      context "really ended" do
        let(:end_at) { Time.current - 3.days }
        it "is falsey" do
          expect(promoted_alert.live?).to be_falsey
          expect(promoted_alert.should_update_facebook?).to be_falsey
          expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([])
        end
      end
    end
  end

  describe "admin differences" do
    let(:promoted_alert_plan) { FactoryBot.create(:promoted_alert_plan, ad_radius_miles: 24) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, approved: true) }
    let(:promoted_alert) do
      FactoryBot.create(:promoted_alert,
        promoted_alert_plan: promoted_alert_plan,
        ad_radius_miles: 333,
        stolen_record: stolen_record,
        admin: admin)
    end
    let(:admin) { false }
    it "is default attributes" do
      expect(promoted_alert.reload.ad_radius_miles).to eq 24
      expect(promoted_alert.activateable?).to be_falsey
      promoted_alert.facebook_data = {activating_at: Time.current.to_i}
      expect(promoted_alert.notify?).to be_truthy
      expect(PromotedAlert.cities_count).to eq([["Canada", "Vancouver", nil, 1]])
    end
    context "admin" do
      let(:admin) { true }
      it "is what is set" do
        expect(promoted_alert.reload.ad_radius_miles).to eq 333
        expect(promoted_alert.activateable?).to be_truthy
        promoted_alert.facebook_data = {activating_at: Time.current.to_i}
        expect(promoted_alert.notify?).to be_falsey
      end
    end
  end
end
