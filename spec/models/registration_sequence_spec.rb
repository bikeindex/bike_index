require "rails_helper"

RSpec.describe RegistrationSequence, type: :model do
  describe ".template" do
    it "creates the template, and is idempotent" do
      expect { RegistrationSequence.template }.to change(RegistrationSequence, :count).by(1)

      template = RegistrationSequence.template
      expect(template).to be_template
      expect(template.organization_id).to be_nil

      expect { RegistrationSequence.template }.to_not change(RegistrationSequence, :count)
    end

    context "when a concurrent request wins the create race" do
      it "rescues RecordNotUnique and returns the existing template" do
        existing = FactoryBot.create(:registration_sequence_template)
        templates = RegistrationSequence.templates
        allow(RegistrationSequence).to receive(:templates).and_return(templates)
        allow(templates).to receive(:first_or_create!).and_raise(ActiveRecord::RecordNotUnique)

        expect(RegistrationSequence.template).to eq(existing)
      end
    end
  end

  describe ".draft_for" do
    let(:organization) { FactoryBot.create(:organization) }

    it "builds a draft cloning the template pages" do
      template = RegistrationSequence.template
      template.registration_sequence_pages.create!(title: "Battery", subtitle: "Charge safely", bullet_points: ["<p>Hello</p>"], listing_order: 0)

      draft = RegistrationSequence.draft_for(organization)

      expect(draft).to be_draft
      expect(draft.organization).to eq(organization)
      page = draft.registration_sequence_pages.first
      expect(page.title).to eq("Battery")
      expect(page.subtitle).to eq("Charge safely")
      expect(page.bullet_points).to eq(["<p>Hello</p>"])
    end

    context "with an existing draft" do
      let!(:existing) { FactoryBot.create(:registration_sequence, organization:) }

      it "returns the existing draft without creating another" do
        expect { RegistrationSequence.draft_for(organization) }.to_not change(RegistrationSequence, :count)
        expect(RegistrationSequence.draft_for(organization)).to eq(existing)
      end
    end

    context "when a concurrent request wins the create race" do
      let!(:existing) { FactoryBot.create(:registration_sequence, organization:) }

      it "rescues RecordNotUnique and returns the existing draft" do
        drafts = RegistrationSequence.draft
        allow(RegistrationSequence).to receive(:draft).and_return(drafts)
        allow(drafts).to receive(:find_by).with(organization:).and_return(nil)
        allow(RegistrationSequence).to receive(:build_draft_for).and_raise(ActiveRecord::RecordNotUnique)

        expect(RegistrationSequence.draft_for(organization)).to eq(existing)
      end
    end
  end

  describe "#make_active!" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:approver) { FactoryBot.create(:superuser) }
    let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

    it "ends the prior active and makes the draft active" do
      expect(draft.make_active!(approver)).to be_truthy

      expect(draft.reload).to be_active
      expect(draft.start_at).to be_present
      expect(draft.approved_by).to eq(approver)
      expect(active.reload).to be_archived
      expect(active.end_at).to be_present
      expect(organization.registration_sequences.active.count).to eq(1)
    end

    context "draft without pages" do
      let!(:draft) { FactoryBot.create(:registration_sequence, organization:) }

      it "does not become active" do
        expect(draft.make_active!(approver)).to be_falsey
        expect(draft.reload).to be_draft
        expect(active.reload).to be_active
      end
    end
  end
end
