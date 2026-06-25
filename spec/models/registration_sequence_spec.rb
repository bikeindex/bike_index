require "rails_helper"

RSpec.describe RegistrationSequence, type: :model do
  describe ".template" do
    it "creates and seeds the template, and is idempotent" do
      expect { RegistrationSequence.template }.to change(RegistrationSequence, :count).by(1)

      template = RegistrationSequence.template
      expect(template).to be_template
      expect(template.organization_id).to be_nil
      expect(template.pages.count).to eq(RegistrationSequence::DEFAULT_PAGES.count)

      expect { RegistrationSequence.template }.to_not change(RegistrationSequence, :count)
      expect(template.reload.pages.count).to eq(RegistrationSequence::DEFAULT_PAGES.count)
    end
  end

  describe ".draft_for" do
    let(:organization) { FactoryBot.create(:organization) }

    it "builds a draft cloning the template pages" do
      RegistrationSequence.template
      draft = RegistrationSequence.draft_for(organization)

      expect(draft).to be_draft
      expect(draft.organization).to eq(organization)
      expect(draft.pages.pluck(:body)).to eq(RegistrationSequence::DEFAULT_PAGES.map { |page| page[:body] })
    end

    context "with an existing draft" do
      let!(:existing) { FactoryBot.create(:registration_sequence, organization:) }

      it "returns the existing draft without creating another" do
        expect { RegistrationSequence.draft_for(organization) }.to_not change(RegistrationSequence, :count)
        expect(RegistrationSequence.draft_for(organization)).to eq(existing)
      end
    end
  end

  describe "#make_live!" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:approver) { FactoryBot.create(:superuser) }
    let!(:live) { FactoryBot.create(:registration_sequence_live, :with_pages, organization:) }
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

    it "archives the prior live and makes the draft live" do
      expect(draft.make_live!(approver)).to be_truthy

      expect(draft.reload).to be_live
      expect(draft.approved_by).to eq(approver)
      expect(draft.approved_at).to be_present
      expect(live.reload).to be_archived
      expect(organization.registration_sequences.live.count).to eq(1)
    end

    context "draft without pages" do
      let!(:draft) { FactoryBot.create(:registration_sequence, organization:) }

      it "does not go live" do
        expect(draft.make_live!(approver)).to be_falsey
        expect(draft.reload).to be_draft
        expect(live.reload).to be_live
      end
    end
  end
end
