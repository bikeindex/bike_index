require "rails_helper"

RSpec.describe RegistrationSequenceAcknowledgment, type: :model do
  let(:organization) { FactoryBot.create(:organization) }
  let(:sequence) do
    FactoryBot.create(:registration_sequence_active, :with_pages, organization:,
      acknowledgment_text: "agree to all of it")
  end
  let(:pages) { sequence.registration_sequence_pages.to_a }
  let(:b_param) { BParam.create(origin: "register_flow", params: {bike: {owner_email: "owner@example.com"}}.as_json) }

  describe ".create_for" do
    it "records who agreed, and reads what they agreed to off the sequence" do
      user = FactoryBot.create(:user_confirmed)
      acknowledgment = described_class.create_for(b_param, sequence:, user:)

      expect(acknowledgment).to have_attributes(registration_sequence_id: sequence.id,
        b_param_id: b_param.id, user_id: user.id, owner_email: "owner@example.com",
        acknowledgment_text: "agree to all of it")
      # Stamped by the insert, so it's the moment of agreement
      expect(acknowledgment.acknowledged_at).to eq acknowledgment.created_at
      expect(acknowledgment.acknowledged_at).to be_within(5).of(Time.current)
      # Attesting requires every page, so the whole sequence is what was agreed to
      expect(acknowledgment.acknowledged_pages.pluck(:id)).to match_array(pages.map(&:id))
    end

    context "sequence without its own text" do
      let(:sequence) { FactoryBot.create(:registration_sequence_active, organization:, acknowledgment_text: nil) }

      it "falls back to the default" do
        expect(described_class.create_for(b_param, sequence:).acknowledgment_text)
          .to eq RegistrationSequence::DEFAULT_ACKNOWLEDGMENT_TEXT
      end
    end
  end

  describe "the organization being destroyed" do
    let!(:acknowledgment) { described_class.create_for(b_param, sequence:) }

    it "keeps the record, and the soft-deleted sequence still says what was agreed to" do
      expect { organization.destroy }.to_not change(described_class, :count)
      expect(RegistrationSequence.find_by(id: sequence.id)).to be_nil # gone from the live scope

      expect(acknowledgment.reload.registration_sequence_id).to eq sequence.id
      expect(acknowledgment.owner_email).to eq "owner@example.com"
      expect(acknowledgment.acknowledgment_text).to eq "agree to all of it"
      expect(acknowledgment.acknowledged_pages.pluck(:id)).to match_array(pages.map(&:id))
    end
  end

  describe ".for_organization" do
    let!(:acknowledgment) { described_class.create_for(b_param, sequence:) }
    let!(:other) do
      described_class.create_for(BParam.create(origin: "register_flow"),
        sequence: FactoryBot.create(:registration_sequence_active))
    end

    it "is the acknowledgments against the organization's own sequences" do
      expect(described_class.for_organization(organization).pluck(:id)).to eq([acknowledgment.id])
    end
  end
end
