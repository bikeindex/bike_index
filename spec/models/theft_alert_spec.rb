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
end
