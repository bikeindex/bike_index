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
      hot_sheet_configuration.is_on = true
      expect(hot_sheet_configuration.save).to be_falsey
      expect(hot_sheet_configuration.errors.full_messages.to_s).to match(/location/)
    end
  end

  describe "send_hour" do
    let(:hot_sheet_configuration) { HotSheetConfiguration.new }
    it "makes things integers, makes 0 if invalid" do
      hot_sheet_configuration.send_hour = 12.5
      expect(hot_sheet_configuration.send_hour).to eq 12
      hot_sheet_configuration.send_hour = 24
      expect(hot_sheet_configuration.send_hour).to eq 0
      hot_sheet_configuration.send_hour = -1
      expect(hot_sheet_configuration.send_hour).to eq 0
    end
  end

  describe "search_radius_metric_units?" do
    let(:hot_sheet_configuration) { HotSheetConfiguration.new }
    it "is false, but you can still set kilometers" do
      expect(hot_sheet_configuration.search_radius_metric_units?).to be_falsey
      hot_sheet_configuration.search_radius_kilometers = 400
      expect(hot_sheet_configuration.search_radius_kilometers).to eq 400
    end
    context "not US organization" do
      let(:organization) { FactoryBot.create(:organization, :in_edmonton) }
      let(:location) { organization.locations.first }
      let(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization) }
      it "is truthy" do
        expect(location.country).to eq Country.canada
        expect(location.state).to be_blank # Because we're fucking this up :(
        expect(location.latitude).to be_within(0.1).of 53.5069377

        expect(hot_sheet_configuration.search_radius_metric_units?).to be_truthy
        hot_sheet_configuration.search_radius_kilometers = 400
        expect(hot_sheet_configuration.search_radius_kilometers).to eq 400

        # Also, set default to a round number
        hot_sheet_configuration.search_radius_miles = nil
        hot_sheet_configuration.set_calculated_attributes
        expect(hot_sheet_configuration.search_radius_kilometers).to eq 100
      end
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
                          is_on: true)
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
