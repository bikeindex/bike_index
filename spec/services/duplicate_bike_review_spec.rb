require "spec_helper"
require_relative "../../app/services/duplicate_bike_review"

RSpec.describe DuplicateBikeReview do
  let(:ownership_class) { Struct.new(:id, :previous_ownership_id, :created_at, :user_id, :owner_email, :is_phone, :claimed, :claimed_at) }
  let(:bike_class) { Struct.new(:id, :serial_normalized_no_space, :manufacturer_id, :manufacturer_other, :ownerships, :current_ownership) }
  let(:email) { ["customer", "example.invalid"].join("@") }
  let(:other_email) { ["another", "example.invalid"].join("@") }
  let(:initial) { ownership_class.new(id: 1, created_at: Time.at(100), user_id: 10, owner_email: email) }
  let(:current) { ownership_class.new(id: 2, previous_ownership_id: 1, created_at: Time.at(200), user_id: 20, owner_email: other_email) }
  let(:reference) { bike_class.new(id: 1, serial_normalized_no_space: "ABC123", manufacturer_id: 1, ownerships: [current, initial], current_ownership: current) }
  let(:bike) { bike_class.new(id: 2, serial_normalized_no_space: serial, manufacturer_id: manufacturer_id, manufacturer_other: manufacturer_other, ownerships: [initial], current_ownership: initial) }
  let(:serial) { "ABC123" }
  let(:manufacturer_id) { 1 }
  let(:manufacturer_other) { nil }
  let(:review) { described_class.new(bikes: [reference, bike]) }

  context "matching whole serials with different current owners" do
    it "reports evidence separately without treating serial equality as ownership equality" do
      expect(review.serial_match(bike)).to eq "Whole normalized serial matches"
      expect(review.manufacturer_match(bike)).to eq "Manufacturer matches"
      expect(review.initial_ownership(reference)).to eq initial
      expect(review.account_match(bike, initial: true)).to eq "Same account"
      expect(review.email_match(bike, initial: true)).to eq "Same email"
      expect(review.contact_email(initial)).to eq email
      expect(review.account_match(bike)).to eq "Different accounts"
      expect(review.email_match(bike)).to eq "Different emails"
      expect(review.claim_status(initial)).to eq "Unclaimed"
      expect(review.claim_status(nil)).to eq "Unavailable"
    end
  end

  context "sharing a chunk with different whole serials" do
    let(:serial) { "ABC123XYZ" }
    it "reports different whole serials" do
      expect(review.serial_match(bike)).to eq "Whole normalized serial differs"
    end
  end

  context "short whole serials" do
    let(:serial) { "A" }
    before { reference.serial_normalized_no_space = serial }
    it "compares the entire stored value without a length cutoff" do
      expect(review.serial_match(bike)).to eq "Whole normalized serial matches"
    end
  end

  context "missing whole serial" do
    let(:serial) { nil }
    it "reports unavailable evidence" do
      expect(review.serial_match(bike)).to eq "Whole serial unavailable"
    end
  end

  context "different manufacturer" do
    let(:manufacturer_id) { 2 }
    it "reports the manufacturer mismatch despite serial equality" do
      expect(review.manufacturer_match(bike)).to eq "Manufacturer differs"
    end
  end

  context "missing manufacturer" do
    let(:manufacturer_id) { nil }
    it "does not treat absent manufacturers as matching" do
      expect(review.manufacturer_match(bike)).to eq "Manufacturer unavailable"
    end
  end

  context "different custom manufacturer details" do
    let(:manufacturer_other) { "Custom" }
    it "keeps custom manufacturer differences visible" do
      expect(review.manufacturer_match(bike)).to eq "Custom manufacturer details differ"
    end
  end

  context "email differs only by case and outer whitespace" do
    let(:initial) { ownership_class.new(id: 1, user_id: 10, owner_email: " #{email.upcase} ") }
    before { current.owner_email = email }
    it "reports the exact normalized email match" do
      expect(review.email_match(bike)).to eq "Same email"
    end
  end

  context "phone contact" do
    before { initial.is_phone = true }
    it "does not compare phone contacts as emails" do
      expect(review.email_match(bike, initial: true)).to eq "Email unavailable"
      expect(review.contact_email(initial)).to be_nil
      expect(review.email_evidence(bike, initial: true)).to eq "Email unavailable"
    end
  end

  context "similar emails" do
    before { bike.current_ownership = ownership_class.new(owner_email: compared_email) }

    context "matching local parts with different domains" do
      let(:compared_email) { "another@different.invalid" }

      it "shows a review hint without equating the identities" do
        expect(review.email_evidence(bike)).to eq "Same local part, different domains (identity unverified)"
      end
    end

    context "small spelling differences" do
      let(:compared_email) { "anothre@example.invalid" }

      it "reports two edits without equating the identities" do
        expect(review.email_evidence(bike)).to eq "2 email character edits (identity unverified)"
      end
    end

    context "long addresses" do
      let(:compared_email) { "#{"a" * 260}@example.invalid" }

      it "does not compare unbounded edit distances" do
        expect(review.email_evidence(bike)).to eq "Different emails (identity unverified)"
      end
    end
  end

  context "claim recorded by timestamp" do
    before { initial.claimed_at = Time.at(300) }
    it "recognizes the claim history even without the boolean" do
      expect(review.claim_status(initial)).to eq "Claimed"
    end
  end

  context "missing account and invalid email" do
    before do
      initial.user_id = nil
      initial.owner_email = "unavailable"
    end
    it "does not equate absent identities" do
      expect(review.account_match(bike, initial: true)).to eq "Account unavailable"
      expect(review.email_match(bike, initial: true)).to eq "Email unavailable"
      expect(review.contact_email(initial)).to be_nil
    end
  end

  context "explicit reference record" do
    let(:review) { described_class.new(bikes: [reference, bike], reference_bike: bike) }
    it "uses the requested reference for ownership comparisons" do
      expect(review.reference_bike).to eq bike
      expect(review.account_match(bike)).to eq "Same account"
    end
  end

  context "empty group" do
    let(:review) { described_class.new(bikes: []) }
    it "does not invent matching evidence" do
      expect(review.serial_match(bike)).to eq "Whole serial unavailable"
      expect(review.manufacturer_match(bike)).to eq "Manufacturer unavailable"
      expect(review.account_match(bike, initial: true)).to eq "Account unavailable"
      expect(review.email_match(bike, initial: true)).to eq "Email unavailable"
    end
  end
end
