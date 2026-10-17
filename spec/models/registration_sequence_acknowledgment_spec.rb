require "rails_helper"

RSpec.describe RegistrationSequenceAcknowledgment, type: :model do
  let(:organization) { FactoryBot.create(:organization) }
  let(:sequence) do
    FactoryBot.create(:registration_sequence_active, :with_pages, organization:,
      acknowledgment_text: "agree to all of it")
  end
  let(:pages) { sequence.registration_sequence_pages.to_a }
  let(:b_param) { BParam.create(origin: "register_flow", params: {bike: {owner_email: "owner@example.com"}}.as_json) }

  describe ".acknowledge" do
    let(:acknowledgment) { described_class.find_by(b_param_id: b_param.id) }

    it "records who agreed, and reads what they agreed to off the sequence" do
      user = FactoryBot.create(:user_confirmed)
      expect(described_class.acknowledge(b_param, sequence:, user:)).to be_truthy

      expect(acknowledgment).to have_attributes(registration_sequence_id: sequence.id,
        b_param_id: b_param.id, user_id: user.id, owner_email: "owner@example.com",
        acknowledgment_text: "agree to all of it")
      expect(acknowledgment.acknowledged_at).to be_within(5).of(Time.current)
      # Attesting requires every page, so the whole sequence is what was agreed to
      expect(acknowledgment.acknowledged_pages.pluck(:id)).to match_array(pages.map(&:id))
    end

    context "sequence without its own text" do
      let(:sequence) { FactoryBot.create(:registration_sequence_active, organization:, acknowledgment_text: nil) }

      it "falls back to the default" do
        described_class.acknowledge(b_param, sequence:)
        expect(acknowledgment.acknowledgment_text).to eq RegistrationSequence::DEFAULT_ACKNOWLEDGMENT_TEXT
      end
    end

    context "pending since the bike was created, on a sequence since replaced" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      let(:previous_sequence) { FactoryBot.create(:registration_sequence_active) }
      let!(:pending) do
        described_class.create_pending(b_param, sequence: previous_sequence).tap { it.update(user:) }
      end

      it "acknowledges that one, against the sequence passed, keeping the stand-in creator" do
        expect(described_class.pending.pluck(:id)).to eq([pending.id])
        expect {
          described_class.acknowledge(b_param, sequence:)
        }.to_not change(described_class, :count)
        expect(pending.reload).to have_attributes(registration_sequence_id: sequence.id, user_id: user.id)
        expect(pending.acknowledged_at).to be_present
        expect(described_class.pending.count).to eq 0
      end

      it "records whoever agrees over that stand-in" do
        agreeing = FactoryBot.create(:user_confirmed)
        described_class.acknowledge(b_param, sequence:, user: agreeing)

        expect(pending.reload.user_id).to eq agreeing.id
      end
    end
  end

  describe ".find_for" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:pending) { FactoryBot.create(:registration_sequence_acknowledgment_pending, registration_sequence: sequence, bike:) }

    it "is only an acknowledged one" do
      expect(described_class.find_for(bike:, organization:)).to be_nil

      pending.update(acknowledged_at: Time.current)
      expect(described_class.find_for(bike:, organization:)&.id).to eq pending.id
    end
  end

  describe "the held email" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let!(:pending) do
      FactoryBot.create(:registration_sequence_acknowledgment_pending, registration_sequence: sequence,
        b_param:, bike:)
    end
    let(:initial_ownership) { bike.ownerships.initial.first }
    let(:enqueued) { EmailJobs::OwnershipInvitationJob.jobs.map { it["args"] } }

    it "releases to the ownership it was held for, not whoever owns it now" do
      BikeServices::OwnershipTransferer.find_or_create(bike, updator: nil, new_owner_email: "new@example.com")

      Sidekiq::Job.clear_all
      expect(described_class.acknowledge(b_param, sequence:)).to be_truthy
      expect(enqueued).to eq([[initial_ownership.id]])
    end

    it "releases it when the rules are given up on instead" do
      Sidekiq::Job.clear_all
      expect { pending.abandon! }.to change(described_class, :count).by(-1)
      expect(enqueued).to eq([[initial_ownership.id]])
    end

    # A blanket release on save would send it before the rules were ever agreed to
    it "stays held through a write that isn't the agreement" do
      Sidekiq::Job.clear_all
      pending.update(owner_email: "elsewhere@example.com")
      expect(enqueued).to eq([])
    end
  end

  describe "the organization being destroyed" do
    let!(:acknowledgment) { FactoryBot.create(:registration_sequence_acknowledgment, b_param:, registration_sequence: sequence) }

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
    let!(:acknowledgment) { FactoryBot.create(:registration_sequence_acknowledgment, b_param:, registration_sequence: sequence) }
    let!(:other) { FactoryBot.create(:registration_sequence_acknowledgment) }

    it "is the acknowledgments against the organization's own sequences" do
      expect(described_class.for_organization(organization).pluck(:id)).to eq([acknowledgment.id])
    end
  end
end
