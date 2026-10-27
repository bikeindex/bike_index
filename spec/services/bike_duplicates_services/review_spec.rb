require "rails_helper"

RSpec.describe BikeDuplicatesServices::Review do
  let(:ownership_class) { Struct.new(:id, :previous_ownership_id, :created_at, :user_id, :owner_email, :is_phone, :claimed, :claimed_at, :pos_kind) }
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
  let(:record_class) do
    Struct.new(:id, :created_at, :serial_number, :serial_normalized_no_space, :manufacturer, :manufacturer_id, :manufacturer_other,
      :frame_model, :year, :primary_frame_color, :cycle_type, :propulsion_type, :frame_size, :status, :ownerships, :current_ownership,
      :creation_organization, :deleted_at, :example, :likely_spam, :marketplace_listings, :current_impound_record_id,
      :current_stolen_record_id) do
      def status_stolen? = status == "status_stolen"
    end
  end

  context "matching whole serials with different current owners" do
    it "reports evidence separately without treating serial equality as ownership equality" do
      expect(review.serial_match(bike)).to eq "Whole normalized serial matches"
      expect(review.manufacturer_match(bike)).to eq "Manufacturer matches"
      expect(review.initial_ownership(reference)).to eq initial
      expect(review.account_match(bike, initial: true)).to eq "Same account"
      expect(review.email_evidence(bike, initial: true)).to eq "Exact normalized email"
      expect(review.contact_email(initial)).to eq email
      expect(review.account_match(bike)).to eq "Different accounts"
      expect(review.email_evidence(bike)).to eq "Different emails (identity unverified)"
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
      expect(review.email_evidence(bike)).to eq "Exact normalized email"
    end
  end

  context "phone contact" do
    before { initial.is_phone = true }
    it "does not compare phone contacts as emails" do
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
      expect(review.email_evidence(bike, initial: true)).to eq "Email unavailable"
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
      expect(review.email_evidence(bike, initial: true)).to eq "Email unavailable"
    end
  end

  context "summarizing a larger group" do
    let(:named) { Struct.new(:name) }
    let(:records) do
      [["a@example.com", 2019, 1], ["a@example.com", 2019, 2], ["b@bikeindex.org", 2020, 3], [nil, 2019, 4]].map do |owner_email, year, id|
        ownership = ownership_class.new(id:, created_at: Time.at(id), user_id: owner_email && id, owner_email:)
        record_class.new(id:, created_at: Time.at(id), serial_number: "EN 14764", serial_normalized_no_space: "EN14764",
          manufacturer: named.new("Maker"), frame_model: "Roadster", year:, cycle_type: "bike", propulsion_type: "foot-pedal",
          frame_size: "56cm", status: "status_with_owner", ownerships: [ownership], current_ownership: ownership, marketplace_listings: [])
      end
    end
    let(:review) { described_class.new(bikes: records) }

    it "shows shared values once and the differences per record" do
      expect(review.shared_fields).to eq ["Manufacturer", "Model", "Primary color", "Vehicle type", "Propulsion", "Frame size", "Stored serial", "Whole normalized serial", "Status"]
      expect(review.field_value(records[0], "Propulsion")).to eq "Foot-pedal"
      expect(review.field_value(records[0], "Frame size")).to eq "56CM"
      expect(review.differing_fields).to eq ["Year"]
      expect(review.field_distribution("Year")).to eq [["2019", 3], ["2020", 1]]
      expect(review.differences(records[2])).to eq ["Year"]
      expect(review.differences(records[0])).to eq []
    end

    it "groups by initial contact with absent emails last" do
      expect(review.contact_groups.map { [it.number, it.email, it.bikes.map(&:id)] })
        .to eq [[1, "a@example.com", [1, 2]], [2, "b@bikeindex.org", [3]], [3, nil, [4]]]
      expect(review.contact_group(records[1]).number).to eq 1
    end

    it "derives tentative cues from the loaded records" do
      expect(review.review_contact_count).to eq 2
      expect(review.cues.map(&:key)).to eq ["standard_marking", "review_contact"]
    end
  end

  context "assessing a pair for a future invitation" do
    let(:second_user_id) { 10 }
    let(:pair) do
      [[10, true], [second_user_id, false]].each_with_index.map do |(user_id, claimed), index|
        ownership = ownership_class.new(id: index + 1, created_at: Time.at(index), user_id:, owner_email: "rider@bikeindex.org", claimed:)
        record_class.new(id: index + 1, created_at: Time.at(index), serial_normalized_no_space: "WTU123456", manufacturer_id: 1,
          frame_model: "Roadster", ownerships: [ownership], current_ownership: ownership, marketplace_listings: [])
      end
    end
    let(:review) { described_class.new(bikes: pair) }
    let(:checks) { review.readiness_checks }
    let(:blocked_labels) { checks.select { it.status == :blocked }.map(&:label) }

    it "meets the strict evidence with one known, current, claiming account" do
      expect(checks.map(&:status).uniq).to eq [:pass]
      expect(review.readiness).to eq :pass
    end

    context "with the same email on different accounts" do
      let(:second_user_id) { 11 }

      it "keeps an email-only match tentative" do
        expect(checks.map(&:label)).to include("Same initial email only — tentative; shops and shared inboxes reuse emails")
        expect(review.readiness).to eq :uncertain
      end
    end

    it "vetoes stolen history on the whole serial" do
      FactoryBot.create(:bike, :with_stolen_record, serial_number: "WTU 123456")
      expect(review.readiness_checks.first.label).to eq "Stolen history on this whole serial (any record, manufacturer or status) is a hard merge veto"
      expect(review.readiness).to eq :blocked
    end

    it "keeps test records out" do
      allow(review).to receive(:test_count).and_return(1)
      expect(review.readiness).to eq :blocked
    end

    context "with a stolen record on one record, deleted ones included" do
      before { allow(review).to receive(:stolen_count) { |bike| (bike.id == 2) ? 1 : 0 } }

      it "vetoes it whatever the whole-serial lookup found" do
        expect(blocked_labels).to eq ["A record has its own stolen history, a hard merge veto whatever its serial"]
      end
    end

    context "with a stolen status and no stolen record" do
      before { pair.last.status = "status_stolen" }

      it "vetoes it" do
        expect(blocked_labels).to eq ["A record has its own stolen history, a hard merge veto whatever its serial"]
      end
    end

    context "with a current stolen record" do
      before { pair.last.current_stolen_record_id = 5 }

      it "vetoes it" do
        expect(blocked_labels).to eq ["A record has its own stolen history, a hard merge veto whatever its serial"]
      end
    end

    context "with different whole serials" do
      before { pair.last.serial_normalized_no_space = "WTU123457" }

      it "blocks the comparison" do
        expect(blocked_labels).to eq ["Whole normalized serials differ, or one is missing or shorter than 6 characters"]
      end
    end

    context "with short serials" do
      before { pair.each { it.serial_normalized_no_space = "WTU12" } }

      it "blocks the comparison" do
        expect(blocked_labels).to eq ["Whole normalized serials differ, or one is missing or shorter than 6 characters"]
      end
    end

    context "with a missing serial" do
      before { pair.last.serial_normalized_no_space = nil }

      it "blocks the comparison" do
        expect(blocked_labels).to eq ["Whole normalized serials differ, or one is missing or shorter than 6 characters"]
      end
    end

    context "with different manufacturers" do
      before { pair.last.manufacturer_id = 2 }

      it "blocks the comparison" do
        expect(blocked_labels).to eq ["Manufacturers differ, or one is missing"]
      end
    end

    context "with no manufacturer" do
      before { pair.each { it.manufacturer_id = nil } }

      it "blocks the comparison" do
        expect(blocked_labels).to eq ["Manufacturers differ, or one is missing"]
      end
    end
  end
end
