require "spec_helper"
require "active_support/all"
require "functionable"
require_relative "../../../app/services/serial_normalizer"
require_relative "../../../app/services/bike_services/duplicate_review_finder"
require_relative "../../../app/services/bike_services/duplicate_review_cues"

RSpec.describe BikeServices::DuplicateReviewCues do
  let(:group) do
    {"serial" => "WTU123456", "record_count" => 2, "test_count" => 0, "review_contact_count" => 0,
     "email_count" => 2, "missing_email_count" => 0, "account_count" => 2, "missing_account_count" => 0}
  end
  let(:cue_keys) { described_class.group_cues(group).map(&:key) }

  it "finds standards designations through serial normalization" do
    expect(described_class.standard_marking(["EN14764"])).to eq "EN 14764"
    expect(described_class.standard_marking([SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected("iso 4210-2"))])).to eq "ISO 4210"
    expect(described_class.standard_marking(["WTU123456", nil])).to be_nil
  end

  it "recognizes whole placeholder and part-number serials only" do
    expect(described_class::PLACEHOLDER_SERIALS.keys).to all(be_present)
    expect(described_class::PLACEHOLDER_SERIALS.values_at("N05ER1A1NUM8ER", "N0TA551GNED", "8R0MPT0N", "T08E5PEC1F1ED"))
      .to eq ["NO SERIAL NUMBER", "NOT ASSIGNED", "BROMPTON", "TO BE SPECIFIED"]
    expect(described_class.not_a_serial("170FCTY301")).to have_attributes(kind: :part_number)
    expect(described_class.not_a_serial("XXXXXXXX")).to have_attributes(kind: :placeholder)
    expect(described_class.not_a_serial("8R0MPT0N1234")).to be_nil
    expect(described_class.not_a_serial("WTU123456")).to be_nil
    expect(described_class.not_a_serial("M0T08ECANE", manufacturer_names: {"M0T08ECANE" => "Motobecane"}).value).to eq "manufacturer name Motobecane"
    expect(described_class.cues(serials: ["T08E5PEC1F1ED"], record_count: 2, contact_count: 2, test_count: 0, review_contact_count: 0, single_contact: false).map(&:label))
      .to eq ["Placeholder, not a serial: TO BE SPECIFIED"]
  end

  it "recognizes reserved example domains only" do
    expect(described_class.review_contact?(" Rider@Shop.Example.com ")).to be true
    expect(described_class.review_contact?("rider@shop.test")).to be true
    expect(described_class.review_contact?("rider@example.com.au")).to be false
    expect(described_class.review_contact?("developer@partner.bikeindex.org")).to be false
    expect(described_class.review_contact?(nil)).to be false
  end

  it "gives no cues to an ordinary pair" do
    expect(cue_keys).to eq []
  end

  context "a repeated standards marking with many example contacts" do
    let(:group) { super().merge("serial" => "EN14764", "record_count" => 12, "email_count" => 12, "review_contact_count" => 12) }

    it "explains each cue" do
      expect(cue_keys).to eq %w[standard_marking possible_code review_contact]
      expect(described_class.group_cues(group).find { it.key == "possible_code" }.reason)
        .to include("repeated on 12 live registrations and shared by 12 different initial contact emails")
    end
  end

  it "treats one known contact as context rather than a cue to filter out" do
    single = group.merge("email_count" => 1)
    test_marked = group.merge("test_count" => 1)
    expect(described_class.group_cues(single).map(&:key)).to eq ["single_contact"]
    expect(described_class.filter([single, test_marked], "none").first).to eq [single]
    expect(described_class.filter([single, test_marked], "test_marker").first).to eq [test_marked]
    expect(described_class.filter([single, test_marked], "unknown").first).to eq [single, test_marked]
    expect(described_class.filter([single, test_marked], nil).last).to include("none" => 1, "single_contact" => 1, "test_marker" => 1)
  end

  it "does not call a contact with an unknown sibling a single contact" do
    expect(described_class.group_cues(group.merge("email_count" => 1, "missing_email_count" => 1)).map(&:key)).to eq []
  end
end
