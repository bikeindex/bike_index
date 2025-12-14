# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Binxtils configuration" do
  let(:rails_time_zone) { ActiveSupport::TimeZone[Rails.application.config.time_zone] }

  # Reset to Rails configured time zone before each test to avoid pollution
  before { Binxtils::TimeParser.default_time_zone = rails_time_zone }

  describe "default_time_zone" do
    it "is set to Rails configured time zone" do
      expect(Binxtils::TimeParser.default_time_zone).to eq rails_time_zone
    end

    it "matches the configured Central Time zone" do
      expect(Binxtils::TimeParser.default_time_zone.name).to eq "Central Time (US & Canada)"
    end
  end

  describe "TimeParser.parse" do
    let(:time_str) { "2024-01-15 10:30:00" }

    it "uses the configured default time zone" do
      parsed = Binxtils::TimeParser.parse(time_str)
      expect(parsed.time_zone.name).to eq "Central Time (US & Canada)"
    end

    it "resets Time.zone to default after parsing with different timezone" do
      expect(Time.zone.name).to eq "Central Time (US & Canada)"
      Binxtils::TimeParser.parse(time_str, "America/Los_Angeles")
      expect(Time.zone.name).to eq "Central Time (US & Canada)"
    end
  end

  describe "configurable default_time_zone" do
    it "can be set with a string" do
      Binxtils::TimeParser.default_time_zone = "Pacific Time (US & Canada)"
      expect(Binxtils::TimeParser.default_time_zone.name).to eq "Pacific Time (US & Canada)"
    end

    it "can be set with an ActiveSupport::TimeZone" do
      tz = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
      Binxtils::TimeParser.default_time_zone = tz
      expect(Binxtils::TimeParser.default_time_zone).to eq tz
    end
  end
end
