require "rails_helper"

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

  describe "fetch_stolen_records" do
    let!(:stolen_record) { FactoryBot.create(:stolen_record, :in_nyc) }
    let!(:stolen_record2) { FactoryBot.create(:stolen_record, :in_nyc, date_stolen: Time.current - 2.days) }
    let(:organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization, is_enabled: true) }
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization) }
    it "finds the stolen records, assigns" do
      expect(hot_sheet_configuration).to be_present
      hot_sheet.reload
      expect(hot_sheet.stolen_record_ids).to be_blank
      expect do
        expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id, stolen_record2.id])
      end.to_not change(EmailHotSheetWorker.jobs, :count)
      expect(hot_sheet.stolen_record_ids).to eq([stolen_record.id, stolen_record2.id])
    end
    context "with stolen_record_ids set" do
      let(:hot_sheet) { FactoryBot.create(:hot_sheet, stolen_record_ids: [stolen_record.id]) }
      it "returns the stolen records from stolen_record_ids" do
        expect(hot_sheet.organization.search_coordinates.reject(&:blank?)).to be_blank
        expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id])
      end
    end
  end

  describe "for" do
    let!(:hot_sheet1) { FactoryBot.create(:hot_sheet, created_at: Time.current - 3.days) }
    let(:organization) { hot_sheet1.organization }
    let!(:hot_sheet2) { FactoryBot.create(:hot_sheet, created_at: Time.current - 1.day, organization: organization) }
    it "finds for the day" do
      expect(HotSheet.for(organization, Time.current - 3.days)).to eq hot_sheet1
      expect(HotSheet.for(organization, (Time.current - 3.days).to_date.to_s)).to eq hot_sheet1
      expect(HotSheet.for(organization, (Time.current - 24.hours).to_s)).to eq hot_sheet2
    end
  end
end
