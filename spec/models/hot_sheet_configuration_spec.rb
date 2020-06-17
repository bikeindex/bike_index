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

  describe "send_today_now?" do
    it "is falsey if not enabled" do
      expect(HotSheetConfiguration.new.send_today_now?).to be_falsey
    end
    context "send_today_at after current time" do
      let(:timezone) { ActiveSupport::TimeZone["Atlantic Time (Canada)"] }
      let(:send_seconds) { Time.current.in_time_zone(timezone).seconds_since_midnight + 100 }
      let(:hot_sheet_configuration) do
        FactoryBot.create(:hot_sheet_configuration,
                          send_seconds_past_midnight: send_seconds,
                          timezone_str: "America/Halifax",
                          is_enabled: true)
      end
      it "is falsey" do
        expect(hot_sheet_configuration.time_in_zone.to_i).to be_within(1).of Time.current.utc.to_i # OMG Time math is so hard
        expect(hot_sheet_configuration.timezone.utc_offset).to eq(-14400) # AKA Atlantic Time (Canada)
        expect(hot_sheet_configuration.timezone.utc_offset).to eq timezone.utc_offset
        expect(hot_sheet_configuration.send_today_at.to_i).to be_within(2).of Time.current.to_i + 100
        expect(hot_sheet_configuration.send_today_now?).to be_falsey
      end
      context "send_today_at before current time" do
        let(:send_seconds) { Time.current.in_time_zone(timezone).seconds_since_midnight - 60 }
        it "is truthy - until it's been created" do
          expect(hot_sheet_configuration.send_today_at.to_i).to be_within(2).of Time.current.to_i - 60
          expect(hot_sheet_configuration.hot_sheets.count).to eq 0
          expect(hot_sheet_configuration.send_today_now?).to be_truthy
          # If there is a current hot_sheet, it shouldn't send_today_now
          FactoryBot.create(:hot_sheet, organization: hot_sheet_configuration.organization, sheet_date: Time.current.to_date, delivery_status: "email_success")
          expect(hot_sheet_configuration.send_today_now?).to be_falsey
        end
      end
    end
  end
end
