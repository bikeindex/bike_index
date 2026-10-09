require "spec_helper"
require "functionable"
require_relative "../../../app/services/bike_services/duplicate_review_finder"

RSpec.describe BikeServices::DuplicateReviewFinder do
  let(:group) do
    {"serial_stolen" => false, "record_count" => 2, "test_count" => 0,
     "pos_count" => 0, "customer_count" => 2, "claimed_count" => 0,
     "ever_claimed_count" => 0, "transfer_count" => 0,
     "email_count" => 1, "missing_email_count" => 0,
     "account_count" => 1, "missing_account_count" => 0,
     "organization_count" => 1, "missing_organization_count" => 0,
     "pos_first" => false, "handoff_priority" => false}
  end

  it "keeps stolen history ahead of test, size and priority classifications" do
    expect(described_class.kind(group.merge("serial_stolen" => true, "test_count" => 2, "handoff_priority" => true))).to eq "stolen_history"
  end

  it "keeps all test records out of customer queues" do
    expect(described_class.kind(group.merge("test_count" => 2))).to eq "internal_test"
  end

  it "keeps mixed test and customer records separate" do
    expect(described_class.kind(group.merge("test_count" => 1))).to eq "mixed_test"
  end

  it "puts large groups ahead of shop repeat and same-identity queues" do
    expect(described_class.kind(group.merge("record_count" => 10, "pos_count" => 10))).to eq "large_group"
  end

  it "takes placeholder and part-number serials out of every duplicate queue, stolen included" do
    expect(described_class.kind(group.merge("serial" => "N05ER1A1NUM8ER", "serial_stolen" => true, "handoff_priority" => true))).to eq "not_a_serial"
  end

  it "recognizes the strictly qualified handoff evidence" do
    expect(described_class.kind(group.merge("handoff_priority" => true))).to eq "handoff_priority"
  end

  context "repeated POS registrations" do
    let(:group) { super().merge("pos_count" => 2) }

    it "recognizes repeated unclaimed records with one known contact and organization" do
      expect(described_class.kind(group)).to eq "pos_repeat"
    end

    it "does not infer one customer from one known email and an unknown email" do
      expect(described_class.kind(group.merge("missing_email_count" => 1, "missing_account_count" => 1))).to eq "unresolved"
    end

    it "does not infer one shop from an absent organization" do
      expect(described_class.kind(group.merge("missing_organization_count" => 1))).to eq "same_identity"
    end

    it "does not treat a claimed initial registration as an unclaimed repeat" do
      expect(described_class.kind(group.merge("ever_claimed_count" => 1))).to eq "same_identity"
    end

    it "preserves transfers for manual review" do
      expect(described_class.kind(group.merge("transfer_count" => 1))).to eq "same_identity"
    end
  end

  context "shop and customer channels" do
    let(:group) { super().merge("pos_count" => 1, "customer_count" => 1, "pos_first" => true) }

    it "only labels the shop-first direction as a possible handoff" do
      expect(described_class.kind(group)).to eq "shop_customer"
      expect(described_class.kind(group.merge("pos_first" => false))).to eq "same_identity"
    end

    it "does not make a handoff group from more than two records" do
      expect(described_class.kind(group.merge("record_count" => 3))).to eq "same_identity"
    end
  end

  it "keeps absent identities unresolved" do
    expect(described_class.kind(group.merge("email_count" => 0, "account_count" => 0))).to eq "unresolved"
  end

  it "keeps differing known identities unresolved" do
    expect(described_class.kind(group.merge("email_count" => 2, "account_count" => 2))).to eq "unresolved"
  end

  it "allows same-account evidence with differing emails without calling it mergeable" do
    expect(described_class.kind(group.merge("email_count" => 2))).to eq "same_identity"
  end
end
