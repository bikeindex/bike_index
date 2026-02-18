# frozen_string_literal: true

require "rails_helper"

# Tests to define what this custom matcher should do
# file is config/lib because if it was in support it would be required by rails_helper.rb
RSpec.describe "custom have_attributes and RspecHashMatcher" do
  let(:options) { RspecHashMatcher::DEFAULT_OPTS }
  context "with two hashes" do
    describe "have_attributes" do
      let(:time) { Time.current }
      let(:hash_1) { {:something => 12, "else" => "party", :time => time} }
      let(:hash_2) { {"something" => 12.0, :else => :party, :time => time + 0.1} }

      it "matches indifferently" do
        expect(RspecHashMatcher.recursive_match_hashes_errors(hash_1, hash_2)).to eq([])
        expect(hash_1).to have_attributes hash_2
      end

      context "with hash_2 missing key" do
        let(:hash_2) { hash_1.except(:something) }
        let(:target_error) do
          [
            {key: "keys", value: %w[else time], match_value: %w[else something time],
             match_with: "equal"}
          ]
        end

        it "doesn't match" do
          expect(RspecHashMatcher.recursive_match_hashes_errors(hash_1, hash_2)).to eq(target_error)
          expect(hash_1).not_to have_attributes hash_2
        end
      end

      context "with hash_1 missing key" do
        let(:hash_1) { hash_2.except(:else) }

        it "doesn't match" do
          expect(hash_1).not_to have_attributes hash_2
        end
      end

      context "with nested hash" do
        let(:hash_1) { {something: {foo: "bar", bar: :foo}} }
        let(:hash_2) { {"something" => {bar: :foo, foo: :bar}}.as_json }

        it "matches" do
          expect(hash_1).to have_attributes hash_2
        end

        context "with a non match" do
          let(:hash_2) { {"something" => {bar: :foo, foo: :bar, barfoo: :foobar}} }

          it "doesn't match" do
            expect(hash_1).not_to have_attributes hash_2
          end
        end
      end

      context "with boolean" do
        let(:hash_1) { {bool: "1", bool_false: false} }
        let(:hash_2) { {bool: true, bool_false: ""} }

        it "matches" do
          expect(hash_1).to have_attributes hash_2
        end
      end
    end

    context "with timezone" do
      let(:time) { Time.at(1657223244) } # 2022-07-07 14:47:24
      let(:hash_1) { {updated_at: time.in_time_zone("Amsterdam")} }
      let(:hash_2) { {updated_at: time.utc.to_s, timezone: "UTC"} }
      it "matches" do
        expect(hash_1).to have_attributes(hash_2)
      end

      context "active record obj has timestamp stored" do
        # NOTE: This is hacky and weird, but I think it's useful to test - and this was easy to set up
        let(:obj) { User.new(email: "something@stuff.com", updated_at: time) }
        let(:hash) { {:email => "something@stuff.com", :updated_at => time.to_i, "timezone" => "UTC"} }
        it "matches" do
          expect(obj).to have_attributes hash
        end
      end
    end
  end

  context "with ActiveRecord model" do
    let(:time) { 1.hour.ago }
    let(:invoice) do
      Invoice.new(amount_due_cents: 2_000, subscription_start_at: time + 0.5)
    end
    let(:hash_1) { {amount_due_cents: "2000.0", subscription_start_at: time} }

    it "matches" do
      expect(RspecHashMatcher.send(:times_match?, invoice.subscription_start_at,
        hash_1[:subscription_start_at])).to be_truthy
      expect(invoice).to have_attributes(hash_1)
    end

    context "with non-matching" do
      let(:hash_2) { hash_1.merge(subscription_start_at: time + 3) }

      it "does not matches" do
        expect(invoice).not_to have_attributes(hash_2)
      end
    end
  end

  describe "validate_options!" do
    it "noops" do
      expect(RspecHashMatcher.send(:validate_options!, options)).to be_nil
    end
    context "with invalid match_number_types" do
      let(:options) { {coerce_values_to_json: true, match_number_types: true} }
      it "raises" do
        expect do
          RspecHashMatcher.send(:validate_options!, options)
        end.to raise_error(/invalid options/i)
      end
    end
  end

  describe "values_match?" do
    context "with number" do
      it "is truthy for matching Integer and Float" do
        expect(options[:match_number_types]).to be_falsey # Sanity check default options
        expect(RspecHashMatcher.send(:values_match?, 12, 12.0, options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, 12.0, 12, options: options)).to be_truthy
      end
      it "is truthy for matching Float and BigDecimal" do
        expect(RspecHashMatcher.send(:values_match?, 12.0, BigDecimal(12), options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, BigDecimal(12), 12, options: options)).to be_truthy
      end
      it "is truthy for matching Number and String" do
        expect(RspecHashMatcher.send(:values_match?, 12.0, "12", options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, "12", 12.0, options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, "12", BigDecimal("12.0"), options: options)).to be_truthy
      end
      it "is falsey if both are strings" do
        expect(RspecHashMatcher.send(:values_match?, "12.0", "12", options: options)).to be_falsey
      end
      context "with match_number_types: true" do
        let(:options) { RspecHashMatcher::DEFAULT_OPTS.merge(match_number_types: true) }
        it "is falsey" do
          expect(RspecHashMatcher.send(:values_match?, 12.0, BigDecimal(12), options: options)).to be_truthy
          expect(RspecHashMatcher.send(:values_match?, 12.0, 12, options: options)).to be_truthy
          expect(RspecHashMatcher.send(:values_match?, 12, 12.00, options: options)).to be_truthy
          expect(RspecHashMatcher.send(:values_match?, 12.0, 12.00, options: options)).to be_truthy
        end
      end
    end
    context "with arrays" do
      it "is truthy for array with different order" do
        expect(options[:match_array_order]).to be_falsey # Sanity check default options
        expect(RspecHashMatcher.send(:values_match?, [1, 2], [2, 1], options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, %w[a b c], %w[b a c], options: options)).to be_truthy
      end

      it "matches by strings" do
        expect(RspecHashMatcher.send(:values_match?, [2], ["2"], options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, [2, "abc", 3], %w[2 abc 3], options: options)).to be_truthy
      end

      it "is falsey for different arrays" do
        expect(RspecHashMatcher.send(:values_match?, [], [2, 1], options: options)).to be_falsey
        expect(RspecHashMatcher.send(:values_match?, %w[a b c], %w[a c], options: options)).to be_falsey
      end

      context "with match_array_order" do
        let(:options) { RspecHashMatcher::DEFAULT_OPTS.merge(match_array_order: true) }
        it "matches based on array order" do
          expect(RspecHashMatcher.send(:values_match?, [1, 2], [2, 1], options: options)).to be_falsey
          expect(RspecHashMatcher.send(:values_match?, %w[a b c], %w[b a c], options: options)).to be_falsey
        end
      end
    end

    context "with times" do
      let(:time_1) { Time.at(1657223244) } # 2022-07-07 14:47:24
      let(:time_2) { time_1.in_time_zone("Amsterdam") } # We

      it "is truthy for times" do
        expect(RspecHashMatcher.send(:values_match?, time_1, time_2, options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, time_2, time_1, options: options)).to be_truthy
      end

      it "is truthy if a time is a timestamp" do
        expect(RspecHashMatcher.send(:values_match?, time_1.to_i, time_2, options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, time_1, time_2.to_i, options: options)).to be_truthy
      end
    end

    context "blanks" do
      it "is truthy for blank vs nil" do
        expect(options[:match_blanks]).to be_falsey # Sanity check default options
        expect(RspecHashMatcher.send(:values_match?, "", nil, options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, nil, " ", options: options)).to be_truthy
        expect(RspecHashMatcher.send(:values_match?, "", "\n", options: options)).to be_truthy
      end
      context "with match_blanks" do
        let(:options) { RspecHashMatcher::DEFAULT_OPTS.merge(match_blanks: true) }
        it "matches based on array order" do
          expect(RspecHashMatcher.send(:values_match?, "", nil, options: options)).to be_falsey
        end
      end
    end
  end

  describe "times_match?" do
    let(:time_1) { Time.at(1_718_123_393) } # 2024-06-11 16:29:53
    let(:time_2) { time_1 - 0.2 }
    let(:round_time_1) { RspecHashMatcher.send(:round_time, time_1) }
    let(:round_time_2) { RspecHashMatcher.send(:round_time, time_2) }

    it "matches the time" do
      RspecHashMatcher.send(:values_match?, 12, 12.0, options: options)
      expect(RspecHashMatcher.send(:times_match?, time_1, time_2)).to be_truthy
    end

    context "with 1 second later" do
      let(:time_2) { time_1 + 1 }

      it "matches the time" do
        expect(RspecHashMatcher.send(:times_match?, time_1, time_2)).to be_truthy
      end
    end

    context "with 1 minute later" do
      let(:time_2) { time_1 + 1.minute }

      it "is falsey" do
        expect(RspecHashMatcher.send(:times_match?, time_1, time_2)).to be_falsey
      end

      context "with match_time_within 10.minutes" do
        it "is truthy" do
          result = RspecHashMatcher.send(:times_match?, time_1, time_2,
            match_time_within: 10.minutes)
          expect(result).to be_truthy
        end
      end
    end
  end
end
