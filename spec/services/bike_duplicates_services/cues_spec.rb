require "rails_helper"

RSpec.describe BikeDuplicatesServices::Cues do
  let(:group) do
    {"serial" => "WTU123456", "record_count" => 2, "test_count" => 0, "review_contact_count" => 0,
     "email_count" => 2, "missing_email_count" => 0, "account_count" => 2, "missing_account_count" => 0}
  end
  let(:cue_keys) { described_class.group_cues(group).map(&:key) }

  def cue_labels(serials) = described_class.cues(serials:, record_count: 2, contact_count: 2, test_count: 0, review_contact_count: 0, single_contact: false).map(&:label)

  it "finds standards designations through serial normalization" do
    expect(cue_labels(["EN14764"])).to eq ["Possible standards marking: EN 14764"]
    expect(cue_labels([SerialNormalizer.no_space(SerialNormalizer.normalized_and_corrected("iso 4210-2"))])).to eq ["Possible standards marking: ISO 4210"]
    expect(cue_labels(["WTU123456", nil])).to eq []
  end

  it "recognizes whole part-number, manufacturer-name and repeated-character serials only" do
    expect(described_class.not_a_serial("170FCTY301")).to have_attributes(kind: :part_number)
    expect(described_class.not_a_serial("XXXXXXXX")).to have_attributes(kind: :placeholder)
    expect(described_class.not_a_serial("WTU123456")).to be_nil
    expect(described_class.not_a_serial("M0T08ECANE", manufacturer_names: {"M0T08ECANE" => "Motobecane"}).value).to eq "manufacturer name Motobecane"
    expect(described_class.not_a_serial("M0T08ECANE1234", manufacturer_names: {"M0T08ECANE" => "Motobecane"})).to be_nil
    expect(cue_labels(["5M88R60"])).to eq ["Part number, not a serial: Shimano SM-BBR60 bottom bracket"]
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
    single, test_marked = [single, test_marked].map { it.merge("cues" => described_class.group_cues(it)) }
    expect(described_class.filter([single, test_marked], "none").first).to eq [single]
    expect(described_class.filter([single, test_marked], "test_marker").first).to eq [test_marked]
    expect(described_class.filter([single, test_marked], "unknown").first).to eq [single, test_marked]
    expect(described_class.filter([single, test_marked], nil).last).to include("none" => 1, "single_contact" => 1, "test_marker" => 1)
  end

  it "does not call a contact with an unknown sibling a single contact" do
    expect(described_class.group_cues(group.merge("email_count" => 1, "missing_email_count" => 1)).map(&:key)).to eq []
  end
end
