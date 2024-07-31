# frozen_string_literal: true

require "rails_helper"

RSpec.describe "custom_expectations spec" do
  describe "expect_hashes_to_match" do
    it "matches hash" do
      expect_hashes_to_match({something: true}, {something: true})
    end
    context "indifferent access" do
      it "matches hash" do
        expect_hashes_to_match({something: true}, {"something" => true})
      end
    end
    context "ignores types" do
      it "matches hash" do
        expect_hashes_to_match({something: true, num: 12}, {something: "true", num: "12"})
      end
    end
    context "nesting" do
      it "matches hash" do
        expect_hashes_to_match({something: {else: true}}, {something: {else: true}})
        # Should make a nice error if it doesn't match
        expect {
          expect_hashes_to_match({something: {else: true}}, {something: {else: false, thing: true}})
        }.to raise_error(/something/)
      end
    end
    context "match_time_within" do
      let(:time) { Time.at(1657071309) } # 2022-07-05 18:35:09
      let(:hash1) { {something: "fadf", created_at: time + 0.2} }
      it "matches hash" do
        expect_hashes_to_match(hash1, hash1.merge(created_at: time), match_time_within: 1)
        # Should print out a nice error
        expect {
          expect_hashes_to_match(hash1, hash1.merge(created_at: time), match_time_within: 0)
        }.to raise_error(/created_at/)
      end
      it "matches with timestamp" do
        expect_hashes_to_match(hash1, hash1.merge(created_at: time.to_i), match_time_within: 1)
        # It works if timestamp is in either position
        expect_hashes_to_match(hash1.merge(created_at: time.to_i), hash1, match_time_within: 1)
        # Should print out a nice error
        expect {
          expect_hashes_to_match(hash1, hash1.merge(created_at: time.to_i), match_time_within: 0)
        }.to raise_error(/created_at/)
      end
    end
  end

  describe "expect_attrs_to_match_hash" do
    let(:obj) { Rating.new(timezone: "", submitted_url: "https://example.com") }
    let(:hash) { {timezone: "America/party", submitted_url: "https://example.com"} }

    it "matches" do
      expect_attrs_to_match_hash(obj, hash)
      expect {
        expect_attrs_to_match_hash(obj, hash.merge(id: 11))
      }.to raise_error(/id/)
    end

    context "match_timezone" do
      let(:obj) { Rating.new(submitted_url: "http://example.com", learned_something: true, timezone: nil) }
      let(:hash) { {submitted_url: "http://example.com", learned_something: "true", timezone: "Europe/Kyiv"} }
      it "doesn't match if timezone is incorrect" do
        expect(obj.timezone).to_not eq hash[:timezone]
        # Timezone is ignored! This is the desired behavior, because timezone is submitted with requests and used to set the time
        expect_attrs_to_match_hash(obj, hash)
        # HOWEVER - sometimes we want to match timezone
        expect {
          expect_attrs_to_match_hash(obj, hash, match_timezone: true)
        }.to raise_error(/timezone/)
        # But if timezone is set, it does match
        obj.timezone = "Europe/Kyiv"
        expect_attrs_to_match_hash(obj, hash, match_timezone: true)
      end
    end

    context "boolean" do
      let(:boolean_hash) { hash.merge(learned_something: "false") }
      it "uses params normalizer" do
        expect(obj.learned_something).to be_falsey
        expect_attrs_to_match_hash(obj, boolean_hash)
        expect_attrs_to_match_hash(obj, boolean_hash.merge(learned_something: nil))
        expect_attrs_to_match_hash(obj, boolean_hash.merge(learned_something: "0"))
        expect_attrs_to_match_hash(obj, boolean_hash, match_time_within: 1)
      end
      context "truthy boolean" do
        let(:boolean_hash) { hash.merge(learned_something: "true") }
        it "uses params normalizer" do
          obj.learned_something = true
          expect_attrs_to_match_hash(obj, boolean_hash)
          expect_attrs_to_match_hash(obj, boolean_hash.merge(learned_something: "1"))
        end
      end
    end

    context "match_time_within" do
      let(:time) { Time.current - 5.minutes }
      let(:obj) { User.new(email: "something@stuff.com", id: 12, updated_at: time + 0.2) }
      let(:hash) { {email: "something@stuff.com", id: "12", updated_at: time} }
      it "matches" do
        expect_attrs_to_match_hash(obj, hash) # defaults to having match_time_within
        expect_attrs_to_match_hash(obj, hash.merge(updated_at: time.to_i + 5), match_time_within: 5)
        expect_attrs_to_match_hash(obj, hash.as_json, match_time_within: 1)
        expect {
          expect_attrs_to_match_hash(obj, hash.merge(updated_at: time + 12), match_time_within: 1)
        }.to raise_error(/within/)
      end

      it "defaults to match_time_within" do
        expect_attrs_to_match_hash(obj, hash.as_json)
        expect {
          # Override to not match_time_within
          expect_attrs_to_match_hash(obj, hash.as_json, match_time_within: false)
        }.to raise_error(/updated_at/)
      end

      context "with timezone" do
        let(:time) { Time.at(1657223244) } # 2022-07-07 14:47:24
        let(:hash_with_timezone) { hash.merge(updated_at: "2022-07-07 19:47:24", timezone: "UTC") }
        it "matches" do
          time_utc = TranzitoUtils::TimeParser.parse(hash_with_timezone[:updated_at], hash_with_timezone[:timezone])
          expect(time_utc).to be_within(1).of time
          expect_attrs_to_match_hash(obj, hash_with_timezone)

          # If timezone isn't included, it raises because it parses without timezone
          expect {
            expect_attrs_to_match_hash(obj, hash_with_timezone.except(:timezone))
          }.to raise_error(/updated_at/)
        end
      end

      context "obj has timestamp stored" do
        # NOTE: This is hacky and weird, but I think it's useful to test - and this was easy to set up
        let(:obj) { User.new(email: "something@stuff.com", id: time.to_i) }
        let(:hash) { {email: "something@stuff.com", id: time} }
        it "matches" do
          expect_attrs_to_match_hash(obj, hash, match_time_within: 1)
        end
      end
    end
  end
end
