require "rails_helper"

RSpec.describe TimeParser, type: :service do
  let(:subject) { described_class }
  let(:default_time_zone) { TimeParser::DEFAULT_TIME_ZONE }
  before { Time.zone = default_time_zone }

  describe "parse" do
    context "America/Los_Angeles" do
      let(:target_timestamp) { 1454925600 }
      let(:time_str) { "2016-02-08 04:00:00" }

      it "parses with time_zone, without and with unreadable time_zones" do
        expect(subject.parse(time_str, "America/Chicago").to_i).to eq target_timestamp
        expect(subject.parse(time_str).to_i).to eq target_timestamp
        expect(subject.parse(time_str, "America/PartyCity").to_i).to eq target_timestamp
      end
    end

    context "with in_time_zone" do
      let(:time_str) { "2016-02-08 02:00:00" }
      let(:target_time) { Time.at(1454896800) }
      let(:target_time_central) { Time.at(1454918400) }
      let(:utc_name) { "UTC" }

      context "times with unreadable time_zones" do
        let(:target_time_in_los_angeles) { Time.at(1454925600) }
        let(:time_in_los_angeles) { subject.parse(time_str, "America/Los_Angeles", in_time_zone: true) }
        let(:time_in_fake) { subject.parse(time_str, "America/PartyCity", in_time_zone: true) }
        it "parses" do
          expect(Time.zone.name).to eq default_time_zone.name
          expect(time_in_los_angeles).to match_time target_time_in_los_angeles
          expect(time_in_los_angeles.time_zone.name).to eq "America/Los_Angeles"

          expect(time_in_fake).to match_time target_time_central
          expect(time_in_fake.time_zone.name).to eq utc_name
        end
      end
      context "times without time_zones" do
        let(:time_not_zoned) { subject.parse(time_str, in_time_zone: true) }
        let(:time_in_blank) { subject.parse(time_str, "", in_time_zone: true) }
        it "parses" do
          expect(time_not_zoned).to match_time target_time_central
          expect(time_not_zoned.time_zone.name).to eq utc_name

          expect(time_in_blank).to match_time target_time_central
          expect(time_in_blank.time_zone.name).to eq utc_name
          # current zone is reset
          expect(Time.zone.name).to eq default_time_zone.name
        end
      end
      context "in Reykjavik" do
        let(:time_in_reykjavik) { subject.parse(time_str, "Atlantic/Reykjavik", in_time_zone: true) }
        let(:time_in_utc) { subject.parse(time_str, "UTC", in_time_zone: true) }

        it "parses in other time zones" do
          expect(Time.zone.name).to eq default_time_zone.name
          expect(time_in_reykjavik).to match_time target_time # reykjavik has UTC offset
          expect(time_in_reykjavik.time_zone.name).to eq "Atlantic/Reykjavik"

          expect(time_in_utc).to match_time target_time
          expect(time_in_utc.time_zone.name).to eq "UTC"
          expect(Time.zone.name).to eq default_time_zone.name
        end
      end

      context "in Mexico City" do
        let(:time_in_mexico_city) { subject.parse(time_str, "Mexico City", in_time_zone: true) }
        let(:target_time) { Time.at(1454896800) + 6.hours } # To match Mexico city time

        it "parses in other time zones" do
          expect(time_in_mexico_city).to match_time target_time
          expect(time_in_mexico_city.time_zone.name).to eq "Mexico City"
        end

        context "time string with zone information" do
          let(:time_str) { "2016-02-08T02:00:00.00000-06:00" }
          let(:time_in_mexico_city) { subject.parse(time_str, in_time_zone: true) }

          it "parses from time_str with zone" do
            expect(time_in_mexico_city).to match_time target_time
            expect(time_in_mexico_city.time_zone.tzinfo.name).to eq "America/Chicago"
            # current zone is reset
            expect(Time.zone.name).to eq default_time_zone.name
          end
          it "parses the same time with in_time_zone false" do
            time = subject.parse(time_str, in_time_zone: false)
            expect(time).to match_time time_in_mexico_city
            expect(time.time_zone&.name).to eq default_time_zone.name
          end

          context "also passed time_zone" do
            let(:time_in_mexico_city) { subject.parse(time_str, "Mexico City", in_time_zone: true) }
            let(:time_in_los_angeles) { subject.parse(time_str, "America/Los_Angeles", in_time_zone: true) }
            let(:time_from_timestamp) do
              timestamp = time_in_mexico_city.to_i
              subject.parse(timestamp, "Mexico City", in_time_zone: true)
            end
            it "parses in the time_str and returns in the time_zone" do
              expect(time_in_mexico_city).to match_time target_time
              expect(time_in_mexico_city.time_zone.name).to eq "Mexico City"
              # current zone is reset
              expect(Time.zone.name).to eq default_time_zone.name
            end
            it "ignores the passed time_zone while parsing, but returns in it" do
              expect(time_in_los_angeles).to match_time target_time
              expect(time_in_los_angeles.time_zone.name).to eq "America/Los_Angeles"
              # current zone is reset
              expect(Time.zone.name).to eq default_time_zone.name
            end
            it "ignores the passed time_zone while parsing timestamps, but returns in it" do
              expect(time_from_timestamp).to match_time target_time
              expect(time_from_timestamp.time_zone.name).to eq "Mexico City"
              # current zone is reset
              expect(Time.zone.name).to eq default_time_zone.name
            end
          end
        end
      end
    end

    context "UTC" do
      let(:target_time) { 1454814602 }
      let(:time_str) { "2016-02-07 03:10:02" }

      it "parses with UTC time_zone and with a place in UTC" do
        expect(subject.parse(time_str, "UTC").to_i).to eq target_time
        expect(subject.parse(time_str, "Atlantic/Reykjavik").to_i).to eq target_time
        expect(subject.parse(time_str).to_i).to_not eq target_time
      end
    end

    context "nil" do
      it "returns nil" do
        expect(subject.parse(" ")).to be_nil
        expect(subject.parse(nil)).to be_nil
      end
    end

    context "with cray IE 11 time params" do
      let(:target_time) { 1538283600 }
      let(:target_time_in_uk) { 1538262000 }
      let(:time_str) { "09/30/2018" }

      it "parses it, resets the zone over and over again" do
        expect(Time.zone).to eq default_time_zone
        expect(subject.parse(time_str, "").to_i).to eq target_time
        expect(Time.zone).to eq default_time_zone
        expect(subject.parse(time_str, "Europe/London").to_i).to eq target_time_in_uk
        expect(Time.zone).to eq default_time_zone
      end
    end

    context "time" do
      let(:time) { Time.current - 55.minutes }

      it "returns the time" do
        expect(subject.parse(time)).to be_within(1).of time
      end
    end

    context "date" do
      let(:time) { Date.today }

      it "returns the time" do
        expect(subject.parse(time).to_date).to eq time
      end
    end

    context "2017-3" do
      let(:target_date) { Date.parse("2017-03-01") }

      it "parses out the beginning of the month" do
        expect(subject.parse("2017-3").to_date).to eq target_date
        expect(subject.parse("2017-3", "Europe/London").to_date).to eq target_date
        expect(subject.parse("2017-03").to_date).to eq target_date
        expect(subject.parse("2017-03-").to_date).to eq target_date
        expect(subject.parse("2017/03").to_date).to eq target_date
        # And all the reverse, for americans
        expect(subject.parse("3-2017").to_date).to eq target_date
        expect(subject.parse("3/2017").to_date).to eq target_date
        expect(subject.parse("03/2017").to_date).to eq target_date
      end
    end

    context "2019" do
      let(:target_date) { Date.parse("2019-01-01") }

      it "returns 2019-01-01" do
        expect(subject.parse("2019").to_date).to eq target_date
        expect(subject.parse("1999").to_date).to eq(target_date - 20.years)
      end
    end

    context "not a date" do
      it "errors" do
        expect {
          subject.parse("3fbd3770-1b71-4f21-8647-a1804e404aca")
        }.to raise_error(ArgumentError)
      end
    end

    context "with time_zone" do
      let(:time_zone) { "Central Time (US & Canada)" }
      let(:time) { (Time.current - 5.minutes).in_time_zone(time_zone) }
      it "returns with time_zone" do
        expect(subject.parse(time)).to eq time
        parsed_time = subject.parse(time)
        expect(parsed_time).to eq time
        expect(parsed_time.time_zone.name).to eq time_zone
        expect(TimeZoneParser.parse(time_zone)).to eq parsed_time.time_zone
      end
    end
  end
end
