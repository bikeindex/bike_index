require "rails_helper"

RSpec.describe HotSheetConfiguration, type: :model do
  describe "factory" do
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration) }
    it "is valid" do
      expect(hot_sheet_configuration.valid?).to be_truthy
      expect(hot_sheet_configuration.id).to be_present
    end
  end

  describe "validates bounding_box" do
    let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["hot_sheet"]) }
    let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization) }
    it "ensures there is a search location" do
      expect(hot_sheet_configuration.valid?).to be_truthy
      hot_sheet_configuration.is_enabled = true
      expect(hot_sheet_configuration.save).to be_falsey
      expect(hot_sheet_configuration.errors.full_messages.to_s).to match(/location/)
    end
  end

  describe "create_today_now?" do
    it "is falsey if not enabled" do
      expect(HotSheetConfiguration.new.create_today_now?).to be_falsey
    end
    context "with send_at_today after current time" do

    end
  end
end
