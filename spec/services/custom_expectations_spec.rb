# frozen_string_literal: true

require "rails_helper"

RSpec.describe "custom_expectations matcher" do
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
          expect_hashes_to_match({something: {else: true}}, {something: {else: false}})
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
    let(:obj) { User.new(email: "something@stuff.com", id: 12) }
    let(:hash) { {email: "something@stuff.com", id: "12"} }

    it "matches" do
      expect_attrs_to_match_hash(obj, hash)
      expect {
        expect_attrs_to_match_hash(obj, hash.merge(id: 11))
      }.to raise_error(/id/)
    end

    context "match_time_within" do
      let(:time) { Time.current - 5.minutes }
      let(:obj) { User.new(email: "something@stuff.com", id: 12, updated_at: time + 0.2) }
      let(:hash) { {email: "something@stuff.com", id: "12", updated_at: time} }
      it "matches" do
        expect_attrs_to_match_hash(obj, hash, match_time_within: 1)
        expect_attrs_to_match_hash(obj, hash.merge(updated_at: time.to_i + 5), match_time_within: 5)
        expect_attrs_to_match_hash(obj, hash.as_json, match_time_within: 1)
        expect {
          expect_attrs_to_match_hash(obj, hash.merge(updated_at: time + 12), match_time_within: 1)
        }.to raise_error(/within/)
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
