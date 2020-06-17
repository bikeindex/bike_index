require "rails_helper"

RSpec.describe HotSheet, type: :model do
  describe "factory" do
    let(:hot_sheet) { FactoryBot.build(:hot_sheet, sheet_date: "2020-06-07") }
    let(:organization) { hot_sheet.organization }
    it "is valid" do
      hot_sheet.save
      expect(hot_sheet.valid?).to be_truthy
      expect(hot_sheet.id).to be_present
      expect(hot_sheet.email_success?).to be_falsey
      expect(HotSheet.for(organization, Date.parse("2020-06-07"))).to eq hot_sheet
      expect(hot_sheet.subject).to eq "Hot Sheet: Sunday, Jun 7"
      expect(hot_sheet.previous_sheet).to be_blank
      expect(hot_sheet.next_sheet).to be_blank
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
      expect(hot_sheet.fetch_stolen_records.pluck(:id)).to eq([stolen_record.id, stolen_record2.id])
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

  describe "fetch_recipients" do
    let(:organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    let!(:membership) { FactoryBot.create(:membership_claimed, organization: organization, hot_sheet_notification: "notification_daily") }
    let!(:membership2) { FactoryBot.create(:membership_claimed, organization: organization, hot_sheet_notification: "notification_never") }
    let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization) }
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization) }
    it "finds the recipients" do
      expect(organization.memberships.pluck(:id)).to match_array([membership.id, membership2.id])
      expect(hot_sheet.recipient_ids).to be_nil
      expect(hot_sheet.fetch_recipients.pluck(:id)).to eq([membership.user_id])
      hot_sheet.reload
      expect(hot_sheet.recipient_ids).to eq([membership.user_id])
    end
    context "with recipient_ids set" do
      let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization, recipient_ids: [membership.user_id, membership2.user_id]) }
      it "returns the set recipients" do
        hot_sheet.reload
        expect(hot_sheet.fetch_recipients.pluck(:id)).to match_array([membership.user_id, membership2.user_id])
      end
    end
  end

  describe "for" do
    let!(:hot_sheet1) { FactoryBot.create(:hot_sheet, sheet_date: Time.current - 2.days) }
    let(:organization) { hot_sheet1.organization }
    let!(:hot_sheet2) { FactoryBot.create(:hot_sheet, sheet_date: Time.current - 1.day, organization: organization) }
    let!(:hot_sheet3) { FactoryBot.create(:hot_sheet, sheet_date: Time.current.to_date, organization: organization) }
    it "finds for the day" do
      expect(HotSheet.for(organization, (Time.current - 2.days).to_date)).to eq hot_sheet1
      expect(HotSheet.for(organization, (Time.current - 1.days).to_date)).to eq hot_sheet2
      expect(HotSheet.for(organization, Time.current.to_date)).to eq hot_sheet3
      current_hot_sheet = HotSheet.for(organization)
      expect(current_hot_sheet.current?).to be_truthy
      expect(current_hot_sheet.next_sheet&.id).to be_blank
      expect(current_hot_sheet.previous_sheet&.id).to eq hot_sheet3.id

      expect(hot_sheet3.next_sheet&.id).to be_blank
      expect(hot_sheet3.previous_sheet&.id).to eq hot_sheet2.id

      expect(hot_sheet2.next_sheet&.id).to eq hot_sheet3.id
      expect(hot_sheet2.previous_sheet&.id).to eq hot_sheet1.id

      expect(hot_sheet1.next_sheet&.id).to eq hot_sheet2.id
      expect(hot_sheet1.previous_sheet&.id).to be_blank
    end
  end
end
