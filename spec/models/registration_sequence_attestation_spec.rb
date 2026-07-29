require "rails_helper"

RSpec.describe RegistrationSequenceAttestation, type: :model do
  let(:organization) { FactoryBot.create(:organization) }
  let(:sequence) do
    FactoryBot.create(:registration_sequence_active, :with_pages, organization:,
      attestation_text: "agree to all of it")
  end
  let(:pages) { sequence.registration_sequence_pages.to_a }
  let(:b_param) { BParam.create(origin: "register_flow", params: {bike: {owner_email: "owner@example.com"}}.as_json) }

  describe ".create_for" do
    it "snapshots the sequence's text and who agreed to what" do
      user = FactoryBot.create(:user_confirmed)
      attestation = described_class.create_for(b_param, sequence:, user:, page_ids: pages.map(&:id))

      expect(attestation).to have_attributes(registration_sequence_id: sequence.id,
        b_param_id: b_param.id, user_id: user.id, owner_email: "owner@example.com",
        attestation_text: "agree to all of it")
      expect(attestation.attested_at).to be_within(5).of(Time.current)
      expect(attestation.acknowledged_pages.pluck(:id)).to match_array(pages.map(&:id))
    end

    it "falls back to the default text when the sequence has none" do
      sequence.update!(attestation_text: nil)
      expect(described_class.create_for(b_param, sequence:, page_ids: []).attestation_text)
        .to eq RegistrationSequence::DEFAULT_ATTESTATION_TEXT
    end
  end

  describe "outliving the sequence" do
    let!(:attestation) { described_class.create_for(b_param, sequence:, page_ids: pages.map(&:id)) }

    it "survives the organization being destroyed, keeping what was agreed to" do
      expect { organization.destroy }.to_not change(described_class, :count)

      expect(attestation.reload.registration_sequence_id).to be_nil
      expect(attestation.attestation_text).to eq "agree to all of it"
      expect(attestation.acknowledged_page_ids).to match_array(pages.map(&:id))
      # Only the pages themselves are gone
      expect(attestation.acknowledged_pages).to be_nil
    end
  end

  describe ".for_organization" do
    let!(:attestation) { described_class.create_for(b_param, sequence:, page_ids: []) }
    let!(:other) do
      described_class.create_for(BParam.create(origin: "register_flow"),
        sequence: FactoryBot.create(:registration_sequence_active), page_ids: [])
    end

    it "is the attestations against the organization's own sequences" do
      expect(described_class.for_organization(organization).pluck(:id)).to eq([attestation.id])
    end
  end
end
