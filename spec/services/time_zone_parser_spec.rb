require "rails_helper"

RSpec.describe TimeZoneParser, type: :service do
  let(:subject) { described_class }
  let(:default_time_zone) { TimeParser::DEFAULT_TIME_ZONE }
  before { Time.zone = default_time_zone }

  describe "parse" do
    let(:target_time_zone) { ActiveSupport::TimeZone[time_zone_str] }
    context "LA" do
      let(:time_zone_str) { "America/Los_Angeles" }

      it "returns correct time_zone" do
        expect(subject.parse(time_zone_str)).to eq target_time_zone
        expect(subject.parse(time_zone_str).utc_offset).to eq(-28800)
      end
    end

    context "Chicago" do
      let(:time_zone_str) { "America/Chicago" }
      let(:target_time_zone) { ActiveSupport::TimeZone[time_zone_str] }

      it "returns correct time_zone" do
        expect(subject.parse(time_zone_str)).to eq target_time_zone
        expect(subject.parse(time_zone_str).utc_offset).to eq(-21600)
      end
    end

    context "blank" do
      it "returns nil" do
        expect(subject.parse("")).to be_nil
        expect(subject.parse("\n ")).to be_nil
        expect(subject.parse(nil)).to be_nil
      end

      it "returns nil for not found" do
        expect(subject.parse("Gobbledy gook")).to be_nil
        expect(subject.parse("Other crap")).to be_nil
      end

      it "uses default_time_zone if assigned nil" do
        # Verify that assigning nil doesn't actually update the Time.zone - critical for the handling of parse
        Time.zone = nil
        expect(Time.zone).to eq default_time_zone
      end
    end

    context "eating itself" do
      let(:time_zone_str) { "America/Guatemala" }

      it "returns correct time_zone" do
        expect(target_time_zone.utc_offset).to eq(-21600)
        expect(subject.parse(time_zone_str)).to eq target_time_zone
        expect(subject.parse(time_zone_str).utc_offset).to eq(-21600)
        # And it works when you do it again on itself
        parsed_result = subject.parse(time_zone_str)
        expect(subject.parse(parsed_result)).to eq target_time_zone
        expect(subject.parse(parsed_result).utc_offset).to eq(-21600)
      end
    end

    context "America/New York" do
      let(:time_zone_str) { "America/New York" }
      let(:target_time_zone) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"] }

      it "returns correctly" do
        expect(TimeZoneParser.parse(time_zone_str).utc_offset).to eq target_time_zone.utc_offset
        # Alternative time_zone name
        expect(subject.parse("Eastern Time (US & Canada)").utc_offset).to eq target_time_zone.utc_offset
      end
    end
  end

  describe "parse_from_time_string and time_string_has_zone_info?" do
    it "does not return for strings without it" do
      expect(subject.parse_from_time_string("2024-03-14 10:30:00")).to be_blank
      expect(subject.send(:time_string_has_zone_info?, "2024-03-14 10:30:00")).to be_falsey
      expect(subject.send(:time_string_has_zone_info?, "2024-03-14 10:30:00 Local")).to be_falsey
    end

    context "with offsets" do
      it "matches expected formats with offsets" do
        expect(subject.send(:time_string_has_zone_info?, "2024-03-14 10:30:00 +0900")).to be_truthy
        expect(subject.parse_from_time_string("2024-03-14 10:30:00 +0900")&.tzinfo&.name).to eq "Asia/Tokyo"

        expect(subject.send(:time_string_has_zone_info?, "2024-03-14 10:30:00 +09:00")).to be_truthy
        expect(subject.parse_from_time_string("2024-03-14 10:30:00 +09:00")&.tzinfo&.name).to eq "Asia/Tokyo"
      end
    end

    context "utc" do
      it "returns UTC" do
        expect(subject.send(:time_string_has_zone_info?, "2024-03-14 10:30:00 UTC")).to be_truthy
        expect(subject.parse_from_time_string("2024-03-14 10:30:00 UTC")&.name).to eq "UTC"
      end
      it "returns UTC" do
        expect(subject.send(:time_string_has_zone_info?, "2024-03-14T10:30:00Z")).to be_truthy
        expect(subject.parse_from_time_string("2024-03-14T10:30:00Z")&.name).to eq "UTC"
      end
    end

    context "with zones" do
      it "matches expected formats with zones" do
        expect(subject.send(:time_string_has_zone_info?, "2024-03-14 10:30:00 EST")).to be_truthy
        expect(subject.parse_from_time_string("2024-03-14 10:30:00 EST")&.tzinfo&.name).to eq "America/Chicago"
      end
      it "matches expected formats with zones" do
        expect(subject.send(:time_string_has_zone_info?, "2024-03-14 10:30:00 GMT")).to be_truthy
        expect(subject.parse_from_time_string("2024-03-14 10:30:00 GMT")&.name).to eq "UTC"
      end
    end

    it "finds New York" do
      result_1 = described_class.parse_from_time_string("2024-01-01T12:00:00-05:00")
      expect(result_1.tzinfo.name).to eq("America/New_York")
      expect(described_class.full_name(result_1)).to eq "Eastern Time (US & Canada)"

      # Summer time in EDT
      result_2 = described_class.parse_from_time_string("2024-07-01T12:00:00-04:00")
      expect(result_2.tzinfo.name).to eq("America/New_York")
      expect(described_class.full_name(result_2)).to eq "Eastern Time (US & Canada)"

      # Winter time in EST
      result_3 = described_class.parse_from_time_string("2024-01-01T12:00:00-05:00")
      expect(result_3.tzinfo.name).to eq("America/New_York")
      expect(described_class.full_name(result_3)).to eq "Eastern Time (US & Canada)"
    end

    context "edge cases" do
      it "returns nil for strings without zone info" do
        expect(described_class.parse_from_time_string("2024-01-01 12:00:00")).to be_nil
        expect(described_class.parse_from_time_string("12:00:00")).to be_nil
        expect(described_class.parse_from_time_string("2024-01-01")).to be_nil
      end

      it "parses strings with named zones" do
        expect(described_class.parse_from_time_string("2024-01-01 12:00:00 EST").tzinfo.name)
          .to eq("America/New_York")
      end

      it "handles fractional hour offsets" do
        # India (UTC+5:30)
        expect(described_class.parse_from_time_string("2024-01-01T12:00:00+05:30").tzinfo.name)
          .to eq("Asia/Kolkata")
      end

      it "handles various time string formats" do
        formats = [
          "2024-01-01 12:00:00 -0500",          # Standard format
          "2024-01-01T12:00:00-05:00",          # ISO8601
          "Tue, 01 Jan 2024 12:00:00 -0500",    # RFC2822
          "01/01/2024 12:00:00 PM -0500",       # American format
          "January 1, 2024 12:00:00 PM -0500"   # Long format
        ]

        formats.each do |format|
          expect(described_class.parse_from_time_string(format).tzinfo.name).to eq("America/New_York")
        end
      end

      it "handles leap seconds" do
        expect(described_class.parse_from_time_string("2024-12-31T23:59:60-05:00").tzinfo.name)
          .to eq("America/New_York")
      end

      it "handles DST transition times" do
        # # Spring forward doesn't work correctly
        # spring_forward = described_class.parse_from_time_string('2024-03-10T02:30:00-04:00')
        # expect(spring_forward.tzinfo.name).to eq('America/New_York')

        # Fall back
        fall_back = described_class.parse_from_time_string("2024-11-03T01:30:00-04:00")
        expect(fall_back.tzinfo.name).to eq("America/New_York")
      end

      it "handles invalid input" do
        expect(described_class.parse_from_time_string(nil)).to be_nil
        expect(described_class.parse_from_time_string("")).to be_nil
        expect(described_class.parse_from_time_string("not a time")).to be_nil
        # Invalid offset
        expect(described_class.parse_from_time_string("2024-01-01T12:00:00-99:00")).to be_nil
      end
    end
  end

  describe "prioritized_zones_matching_offset" do
    it "returns New York first" do
      time = Time.parse("2024-07-01T12:00:00-04:00")
      # Verify that tzinfo.name still returns the correct thing
      expect(ActiveSupport::TimeZone["America/New_York"].tzinfo.name).to eq "America/New_York"
      expect(described_class.send(:prioritized_zones_matching_offset, time, time.utc_offset).map(&:name))
        .to eq(["Eastern Time (US & Canada)", "Indiana (East)", "Caracas", "Georgetown", "La Paz", "Puerto Rico", "Santiago"])
    end
  end

  describe "parse_from_time_and_offset" do
    it "returns target" do
      time = Time.parse("2024-12-02T03:21:41.629Z")
      result_1 = described_class.parse_from_time_and_offset(time:, offset: -21600)
      expect(result_1.tzinfo.name).to eq "America/Chicago"
      expect(described_class.full_name(result_1)).to eq "Central Time (US & Canada)"

      result_2 = described_class.parse_from_time_and_offset(time:, offset: "-21600")
      expect(result_2.tzinfo.name).to eq "America/Chicago"
      expect(described_class.full_name(result_2)).to eq "Central Time (US & Canada)"

      result_3 = described_class.parse_from_time_and_offset(time:, offset: "-06:00")
      expect(result_3.tzinfo.name).to eq "America/Chicago"
      expect(described_class.full_name(result_3)).to eq "Central Time (US & Canada)"

      result_4 = described_class.parse_from_time_and_offset(time:, offset: "-0600")
      expect(result_4.tzinfo.name).to eq "America/Chicago"
      expect(described_class.full_name(result_4)).to eq "Central Time (US & Canada)"
    end
  end

  describe "full_name" do
    let(:full_name) { "Pacific Time (US & Canada)" }
    let(:time_zone) { TimeZoneParser.parse(full_name) }
    it "returns full name" do
      expect(time_zone.name).to eq full_name
      expect(described_class.full_name(time_zone)).to eq full_name
    end
    context "time_zone with abbr" do
      let(:key_name) { "America/Los_Angeles" }
      let(:time_zone_shorter) { TimeZoneParser.parse(key_name) }
      it "returns the full name" do
        # I HAVE NO IDEA WHY IT'S SO FUCKING HARD AND INCONSISTENT
        # shouldn't this return the same time zone?
        expect(time_zone_shorter.name).to eq key_name
        expect(described_class.full_name(time_zone_shorter)).to eq full_name
      end
    end
  end
end
