require "rails_helper"

RSpec.describe RegistrationSequence, type: :model do
  # The template is the sequence no organization owns, so nil is its organization throughout
  describe ".draft_for(nil) - the template's draft" do
    it "starts an empty draft - nothing sits above the template to clone" do
      expect { RegistrationSequence.draft_for(nil) }.to change(RegistrationSequence, :count).by(1)

      template_draft = RegistrationSequence.draft_for(nil)
      expect(template_draft).to be_template
      expect(template_draft).to be_draft
      expect(template_draft.registration_sequence_pages).to be_empty

      expect { RegistrationSequence.draft_for(nil) }.to_not change(RegistrationSequence, :count)
    end

    context "with a live template" do
      let!(:active) { FactoryBot.create(:registration_sequence_template_active, :with_pages) }

      it "clones the live template, and .active_template stays the live one" do
        template_draft = RegistrationSequence.draft_for(nil)

        expect(template_draft).to be_template
        expect(template_draft).to be_draft
        expect(template_draft.registration_sequence_pages.count).to eq 2
        expect(RegistrationSequence.active_template).to eq active
      end
    end
  end

  describe ".draft_for" do
    let(:organization) { FactoryBot.create(:organization) }

    it "builds a draft cloning the live template's pages and acknowledgment settings" do
      template = FactoryBot.create(:registration_sequence_template, faq_url: "https://example.com/faq",
        acknowledgment_text: "agree to everything")
      template.registration_sequence_pages.create!(title: "Battery", subtitle: "Charge safely",
        heading: "Looks like you have an e-vehicle!", body: "<p>Hello</p>", listing_order: 0,
        organization_specific: true)
      template.make_active!

      draft = RegistrationSequence.draft_for(organization)

      expect(draft).to be_draft
      expect(draft).to have_attributes(organization:, faq_url: "https://example.com/faq",
        acknowledgment: "agree to everything")
      page = draft.registration_sequence_pages.first
      expect(page).to have_attributes(title: "Battery", subtitle: "Charge safely",
        heading: "Looks like you have an e-vehicle!", body: "<p>Hello</p>",
        organization_specific: true)
    end

    it "falls back to the default acknowledgment when there's no live template" do
      expect(RegistrationSequence.draft_for(organization).acknowledgment)
        .to eq RegistrationSequence::DEFAULT_ACKNOWLEDGMENT_TEXT
    end

    it "duplicates template page images into independent blobs" do
      template = FactoryBot.create(:registration_sequence_template)
      template_page = template.registration_sequence_pages.create!(title: "Battery", listing_order: 0,
        body: "<ul><li>Charge safely</li></ul>")
      template_page.image.attach(io: StringIO.new("fake image"), filename: "battery.jpg", content_type: "image/jpeg")
      template.make_active!

      page = RegistrationSequence.draft_for(organization).registration_sequence_pages.first

      expect(page.image).to be_attached
      # A distinct blob means destroying the clone won't purge the template's image
      expect(page.image.blob.id).to_not eq(template_page.image.blob.id)
      expect(page.image.download).to eq("fake image")
      expect(page.image.filename.to_s).to eq("battery.jpg")
    end

    context "with an active sequence" do
      let!(:active) do
        FactoryBot.create(:registration_sequence_active, :with_pages, organization:, faq_url: "https://example.com/live")
      end

      it "clones the live sequence, not the template" do
        template = FactoryBot.create(:registration_sequence_template)
        template.registration_sequence_pages.create!(title: "Template only",
          body: "<ul><li>from template</li></ul>", listing_order: 0)
        template.make_active!

        draft = RegistrationSequence.draft_for(organization)

        expect(draft.faq_url).to eq "https://example.com/live"
        expect(draft.registration_sequence_pages.pluck(:title))
          .to eq(active.registration_sequence_pages.pluck(:title))
        expect(draft.registration_sequence_pages.pluck(:title)).to_not include("Template only")
      end
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

  describe "immutability once activated" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:sequence) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }
    let(:page) { sequence.registration_sequence_pages.first }

    it "is editable as a draft, frozen once active, and archivable after" do
      expect(sequence.update(acknowledgment_text: "still a draft")).to be_truthy
      expect(page.update(title: "still a draft")).to be_truthy
      expect(sequence.reorder_page!(page, 1)).to_not eq false

      expect(sequence.make_active!).to be_truthy

      # An acknowledgment points at these by id, so they can't move under it
      expect(sequence.reload.update(acknowledgment_text: "changed")).to be_falsey
      expect(sequence.errors.full_messages.to_sentence).to match(/can't be edited/)
      expect(sequence.reload.acknowledgment_text).to eq "still a draft"

      expect(page.reload.update(title: "changed")).to be_falsey
      expect(page.reload.title).to eq "still a draft"
      expect(page.destroy).to be_falsey
      # update_all skips callbacks, so reorder guards itself
      expect(sequence.reorder_page!(page, 1)).to eq false

      # Adding a page would rewrite what past registrants agreed to
      expect(RegistrationSequencePage.create(registration_sequence: sequence, title: "Added later"))
        .to_not be_persisted

      # Archiving is the one change activation still allows
      expect(sequence.reload.update(end_at: Time.current)).to be_truthy
      expect(sequence.reload).to be_archived
    end

    it "allows a sequence created together with its pages - nothing can have acknowledged it yet" do
      born_active = FactoryBot.create(:registration_sequence_active, :with_pages,
        organization: FactoryBot.create(:organization))

      expect(born_active).to be_active
      expect(born_active.registration_sequence_pages.count).to eq 2
    end

    it "is soft-deleted with its organization, keeping its pages readable" do
      sequence.make_active!

      expect { organization.destroy }.to_not change(RegistrationSequencePage, :count)
      # Out of the live scope, but still there for the acknowledgments that reference it
      expect(RegistrationSequence.find_by(id: sequence.id)).to be_nil
      deleted = RegistrationSequence.with_deleted.find(sequence.id)
      expect(deleted.deleted_at).to be_present
      expect(deleted.registration_sequence_pages.count).to eq 2
    end
  end

  describe "the template's lifecycle" do
    let!(:template_draft) { FactoryBot.create(:registration_sequence_template, :with_pages) }

    it "activates, freezes, and is superseded by the next draft" do
      expect(template_draft.display_name).to eq "Template Draft"
      expect(RegistrationSequence.active_template).to be_nil

      expect(template_draft.make_active!).to be_truthy
      expect(template_draft.reload).to be_active
      expect(template_draft.display_name).to eq "Template Current"
      expect(RegistrationSequence.active_template).to eq template_draft

      # Frozen like any live sequence - editing means a new draft
      expect(template_draft.update(faq_url: "https://example.com/faq")).to be_falsey

      replacement = RegistrationSequence.draft_for(nil)
      expect(replacement.id).to_not eq template_draft.id
      expect(replacement.make_active!).to be_truthy

      expect(template_draft.reload).to be_archived
      expect(RegistrationSequence.active_template).to eq replacement
      expect(RegistrationSequence.templates.active.count).to eq 1
    end

    it "permits only one template draft" do
      expect { FactoryBot.create(:registration_sequence_template) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "permits only one live template" do
      template_draft.make_active!

      expect { FactoryBot.create(:registration_sequence_template_active) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#make_active!" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

    it "ends the prior active and makes the draft active" do
      expect(draft.make_active!).to be_truthy

      expect(draft.reload).to be_active
      expect(draft.start_at).to be_present
      expect(active.reload).to be_archived
      expect(active.end_at).to be_present
      expect(organization.registration_sequences.active.count).to eq(1)
    end

    context "draft without pages" do
      let!(:draft) { FactoryBot.create(:registration_sequence, organization:) }

      it "does not become active" do
        expect(draft.make_active!).to be_falsey
        expect(draft.reload).to be_draft
        expect(active.reload).to be_active
      end
    end

    context "draft with an incomplete page" do
      it "does not become active" do
        # update_column bypasses validation, the way legacy data could
        draft.registration_sequence_pages.first.update_column(:body, "")
        expect(draft.make_active!).to be_falsey
        expect(draft.reload).to be_draft
      end
    end
  end

  describe "#discard_draft!" do
    let(:organization) { FactoryBot.create(:organization) }

    it "removes the draft and its pages" do
      draft = FactoryBot.create(:registration_sequence, :with_pages, organization:)

      expect { expect(draft.discard_draft!).to be_truthy }
        .to change(RegistrationSequence, :count).by(-1)
        .and change(RegistrationSequencePage, :count).by(-2)
      expect(RegistrationSequence.with_deleted.find_by(id: draft.id)).to be_nil
    end

    it "refuses to discard an activated sequence" do
      active = FactoryBot.create(:registration_sequence_active, :with_pages, organization:)
      expect(active.discard_draft!).to eq false
      expect(active.reload).to be_active
    end
  end

  describe "#reorder_page!" do
    let(:draft) { FactoryBot.create(:registration_sequence) }
    let!(:pages) { FactoryBot.create_list(:registration_sequence_page, 3, registration_sequence: draft) }

    it "moves the page to the position and re-sequences listing_order from zero" do
      draft.reorder_page!(pages.last, 0)

      reordered = draft.registration_sequence_pages.reload
      expect(reordered.pluck(:id)).to eq([pages[2].id, pages[0].id, pages[1].id])
      expect(reordered.pluck(:listing_order)).to eq([0, 1, 2])
    end

    it "clamps an out-of-range position to the end" do
      draft.reorder_page!(pages.first, 99)

      expect(draft.registration_sequence_pages.reload.pluck(:id)).to eq([pages[1].id, pages[2].id, pages[0].id])
    end
  end
end
