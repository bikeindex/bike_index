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

  describe "recovered bike" do
    let(:stolen_record) { FactoryBot.create(:stolen_record_recovered) }
    let!(:stolen_record2) { FactoryBot.create(:stolen_record_recovered) }
    let!(:theft_alert) { FactoryBot.create(:theft_alert, stolen_record: stolen_record) }
    let!(:theft_alert2) { FactoryBot.create(:theft_alert) }
    it "returns the bike" do
      expect(theft_alert.stolen_record).to eq stolen_record
      expect(theft_alert.recovered?).to be_truthy
      expect(StolenRecord.unscoped.with_theft_alerts.pluck(:id)).to match_array([stolen_record.id, theft_alert2.stolen_record_id])
      expect(StolenRecord.recovered.with_theft_alerts.pluck(:id)).to eq([stolen_record.id])
    end
  end

  describe "activateable?" do
    let(:theft_alert) { FactoryBot.create(:theft_alert) }
    it "is false" do
      expect(theft_alert.activateable?).to be_falsey
      expect(theft_alert.missing_location?).to be_truthy
      expect(theft_alert.missing_photo?).to be_truthy
      expect(theft_alert.paid?).to be_falsey
    end
  end

  describe "facebook names" do
    let(:theft_alert_plan) { TheftAlertPlan.new(amount_cents_facebook: 1999) }
    let(:theft_alert) { TheftAlert.new(id: 12, theft_alert_plan: theft_alert_plan) }
    let(:facebook_name) { "Theft Alert 12 - $19.99" }
    it "returns the theft alert plan" do
      expect(theft_alert.facebook_name("campaign")).to eq facebook_name
      expect(theft_alert.facebook_name("adset")).to eq "#{facebook_name} - adset"
      expect(theft_alert.facebook_name("ad")).to eq "#{facebook_name} - ad"
    end
  end
end
