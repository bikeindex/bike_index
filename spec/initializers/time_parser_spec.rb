# encoding: utf-8
require 'spec_helper'

describe TimeParser do
  describe 'initialize' do
    context "Chicago time" do
      let(:target_time) { 1454925600 }
      let(:time_str) { "2016-02-08 04:00:00" }
      it "parses with timezone, without and with unreadable timezones" do
        expect(TimeParser.parse(time_str, "America/Chicago").to_i).to eq target_time
        expect(TimeParser.parse(time_str).to_i).to eq target_time
        expect(TimeParser.parse(time_str, "America/PartyCity").to_i).to eq target_time
      end
    end
    context "UTC" do
      let(:target_time) { 1454814602 }
      let(:time_str) { "2016-02-07 03:10:02" }
      it "parses with UTC timezone and with a place in UTC" do
        expect(TimeParser.parse(time_str, "UTC").to_i).to eq target_time
        expect(TimeParser.parse(time_str, "Atlantic/Reykjavik").to_i).to eq target_time
        expect(TimeParser.parse(time_str).to_i).to_not eq target_time
      end
    end
    context "nil" do
      it "returns nil" do
        expect(TimeParser.parse(" ")).to be_nil
        expect(TimeParser.parse(nil)).to be_nil
      end
    end
  end
  describe "timezone_parser" do
    context "new york" do
      let(:timezone_str) { "America/New York" }
      let(:target_timezone) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"] }
      it "returns correctly" do
        expect(TimeParser.parse_timezone("America/New York").utc_offset).to eq target_timezone.utc_offset
        expect(TimeParser.parse_timezone("Eastern Time (US & Canada)").utc_offset).to eq target_timezone.utc_offset
      end
    end
  end
end
