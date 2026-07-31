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
    it "records who agreed, and reads what they agreed to off the sequence" do
      user = FactoryBot.create(:user_confirmed)
      attestation = described_class.create_for(b_param, sequence:, user:)

      expect(attestation).to have_attributes(registration_sequence_id: sequence.id,
        b_param_id: b_param.id, user_id: user.id, owner_email: "owner@example.com",
        attestation_text: "agree to all of it")
      # Stamped by the insert, so it's the moment of agreement
      expect(attestation.attested_at).to eq attestation.created_at
      expect(attestation.attested_at).to be_within(5).of(Time.current)
      # Attesting requires every page, so the whole sequence is what was agreed to
      expect(attestation.acknowledged_pages.pluck(:id)).to match_array(pages.map(&:id))
    end

    context "sequence without its own text" do
      let(:sequence) { FactoryBot.create(:registration_sequence_active, organization:, attestation_text: nil) }

      it "falls back to the default" do
        expect(described_class.create_for(b_param, sequence:).attestation_text)
          .to eq RegistrationSequence::DEFAULT_ATTESTATION_TEXT
      end
    end
  end

  describe "the organization being destroyed" do
    let!(:attestation) { described_class.create_for(b_param, sequence:) }

    it "keeps the record, and the soft-deleted sequence still says what was agreed to" do
      expect { organization.destroy }.to_not change(described_class, :count)
      expect(RegistrationSequence.find_by(id: sequence.id)).to be_nil # gone from the live scope

      expect(attestation.reload.registration_sequence_id).to eq sequence.id
      expect(attestation.owner_email).to eq "owner@example.com"
      expect(attestation.attestation_text).to eq "agree to all of it"
      expect(attestation.acknowledged_pages.pluck(:id)).to match_array(pages.map(&:id))
    end
  end

  describe ".for_organization" do
    let!(:attestation) { described_class.create_for(b_param, sequence:) }
    let!(:other) do
      described_class.create_for(BParam.create(origin: "register_flow"),
        sequence: FactoryBot.create(:registration_sequence_active))
    end

    it "is the attestations against the organization's own sequences" do
      expect(described_class.for_organization(organization).pluck(:id)).to eq([attestation.id])
    end
  end
end
