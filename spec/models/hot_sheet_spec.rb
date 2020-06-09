require 'rails_helper'

RSpec.describe HotSheet, type: :model do
  describe "factory" do
    let(:hot_sheet) { FactoryBot.build(:hot_sheet) }
    let(:organization) { hot_sheet.organization }
    it "is valid" do
      expect do
        hot_sheet.save
      end.to change(EmailHotSheetWorker.jobs, :count).by 1
      expect(hot_sheet.valid?).to be_truthy
      expect(hot_sheet.id).to be_present
      expect(hot_sheet.email_success?).to be_falsey
      expect(HotSheet.for(organization, Time.current)).to eq hot_sheet
    end
  end

  describe "fetch_bike_ids" do
    let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_nyc) }
    let!(:stolen_record2) { FactoryBot.create(:stolen_record, date_stolen: Time.current - 2.days) }
    let(:organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization, enabled: true) }
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization) }
    it "finds the bike, assigns" do
      expect(hot_sheet.stolen_record_ids).to eq([])
      expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id])
      expect(hot_sheet.stolen_record_ids).to eq([stolen_record.id])
    end
    context "with stolen_record_ids set" do
      let(:hot_sheet) { FactoryBot.create(:hot_sheet, stolen_record_ids: [stolen_record.id]) }
      it "returns the bike from stolen_record_ids" do
        expect(hot_sheet.organization.search_coordinates).to be_blank
        expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id])
      end
    end
  end
end
