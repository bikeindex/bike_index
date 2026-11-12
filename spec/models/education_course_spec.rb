require "rails_helper"

RSpec.describe EducationCourse, type: :model do
  # The default course has no organization, so nil stands in for one throughout
  describe ".draft_for(nil) - the default course's draft" do
    it "starts an empty draft - nothing sits above the default course to clone" do
      expect { EducationCourse.draft_for(nil) }.to change(EducationCourse, :count).by(1)

      default_draft = EducationCourse.draft_for(nil)
      expect(default_draft).to be_default
      expect(default_draft).to be_draft
      expect(default_draft.education_course_pages).to be_empty

      expect { EducationCourse.draft_for(nil) }.to_not change(EducationCourse, :count)
    end

    context "with a live default course" do
      let!(:active) { FactoryBot.create(:education_course_default_active, :with_pages) }

      it "clones the live default course, and .active_default stays the live one" do
        default_draft = EducationCourse.draft_for(nil)

        expect(default_draft).to be_default
        expect(default_draft).to be_draft
        expect(default_draft.education_course_pages.count).to eq 2
        expect(EducationCourse.active_default).to eq active
      end
    end
  end

  describe ".draft_for" do
    let(:organization) { FactoryBot.create(:organization) }

    it "builds a draft cloning the live default course's pages and acknowledgment settings" do
      default_course = FactoryBot.create(:education_course_default, faq_url: "https://example.com/faq",
        acknowledgment_text: "agree to everything")
      default_course.education_course_pages.create!(title: "Battery", subtitle: "Charge safely",
        heading: "Looks like you have an e-vehicle!", body: "<p>Hello</p>", listing_order: 0,
        organization_specific: true)
      default_course.make_active!

      draft = EducationCourse.draft_for(organization)

      expect(draft).to be_draft
      expect(draft).to have_attributes(organization:, faq_url: "https://example.com/faq",
        acknowledgment: "agree to everything")
      page = draft.education_course_pages.first
      expect(page).to have_attributes(title: "Battery", subtitle: "Charge safely",
        heading: "Looks like you have an e-vehicle!", body: "<p>Hello</p>",
        organization_specific: true)
    end

    it "falls back to the default acknowledgment when there's no live default course" do
      expect(EducationCourse.draft_for(organization).acknowledgment)
        .to eq EducationCourse::DEFAULT_ACKNOWLEDGMENT_TEXT
    end

    it "duplicates default page images into independent blobs" do
      default_course = FactoryBot.create(:education_course_default)
      default_page = default_course.education_course_pages.create!(title: "Battery", listing_order: 0,
        body: "<ul><li>Charge safely</li></ul>")
      default_page.image.attach(io: StringIO.new("fake image"), filename: "battery.jpg", content_type: "image/jpeg")
      default_course.make_active!

      page = EducationCourse.draft_for(organization).education_course_pages.first

      expect(page.image).to be_attached
      # A distinct blob means destroying the clone won't purge the default course's image
      expect(page.image.blob.id).to_not eq(default_page.image.blob.id)
      expect(page.image.download).to eq("fake image")
      expect(page.image.filename.to_s).to eq("battery.jpg")
    end

    context "with an active course" do
      let!(:active) do
        FactoryBot.create(:education_course_active, :with_pages, organization:, faq_url: "https://example.com/live")
      end

      it "clones the live course, not the default course" do
        default_course = FactoryBot.create(:education_course_default)
        default_course.education_course_pages.create!(title: "Default only",
          body: "<ul><li>from default</li></ul>", listing_order: 0)
        default_course.make_active!

        draft = EducationCourse.draft_for(organization)

        expect(draft.faq_url).to eq "https://example.com/live"
        expect(draft.education_course_pages.pluck(:title))
          .to eq(active.education_course_pages.pluck(:title))
        expect(draft.education_course_pages.pluck(:title)).to_not include("Default only")
      end
    end

    context "with an existing draft" do
      let!(:existing) { FactoryBot.create(:education_course, organization:) }

      it "returns the existing draft without creating another" do
        expect { EducationCourse.draft_for(organization) }.to_not change(EducationCourse, :count)
        expect(EducationCourse.draft_for(organization)).to eq(existing)
      end
    end

    context "when a concurrent request wins the create race" do
      let!(:existing) { FactoryBot.create(:education_course, organization:) }

      it "rescues RecordNotUnique and returns the existing draft" do
        drafts = EducationCourse.draft
        allow(EducationCourse).to receive(:draft).and_return(drafts)
        allow(drafts).to receive(:find_by).with(organization:).and_return(nil)
        allow(EducationCourse).to receive(:build_draft_for).and_raise(ActiveRecord::RecordNotUnique)

        expect(EducationCourse.draft_for(organization)).to eq(existing)
      end
    end
  end

  describe "immutability once activated" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:course) { FactoryBot.create(:education_course, :with_pages, organization:) }
    let(:page) { course.education_course_pages.first }

    it "is editable as a draft, frozen once active, and archivable after" do
      expect(course.update(acknowledgment_text: "still a draft")).to be_truthy
      expect(page.update(title: "still a draft")).to be_truthy
      expect(course.reorder_page!(page, 1)).to_not eq false

      expect(course.make_active!).to be_truthy

      # An acknowledgment points at these by id, so they can't move under it
      expect(course.reload.update(acknowledgment_text: "changed")).to be_falsey
      expect(course.errors.full_messages.to_sentence).to match(/can't be edited/)
      expect(course.reload.acknowledgment_text).to eq "still a draft"

      expect(page.reload.update(title: "changed")).to be_falsey
      expect(page.reload.title).to eq "still a draft"
      expect(page.destroy).to be_falsey
      # update_all skips callbacks, so reorder guards itself
      expect(course.reorder_page!(page, 1)).to eq false

      # Adding a page would rewrite what past registrants agreed to
      expect(EducationCoursePage.create(education_course: course, title: "Added later"))
        .to_not be_persisted

      # Archiving is the one change activation still allows
      expect(course.reload.update(end_at: Time.current)).to be_truthy
      expect(course.reload).to be_archived
    end

    it "allows a course created together with its pages - nothing can have acknowledged it yet" do
      born_active = FactoryBot.create(:education_course_active, :with_pages,
        organization: FactoryBot.create(:organization))

      expect(born_active).to be_active
      expect(born_active.education_course_pages.count).to eq 2
    end

    it "is soft-deleted with its organization, keeping its pages readable" do
      course.make_active!

      expect { organization.destroy }.to_not change(EducationCoursePage, :count)
      # Out of the live scope, but still there for the acknowledgments that reference it
      expect(EducationCourse.find_by(id: course.id)).to be_nil
      deleted = EducationCourse.with_deleted.find(course.id)
      expect(deleted.deleted_at).to be_present
      expect(deleted.education_course_pages.count).to eq 2
    end
  end

  describe "the default course's lifecycle" do
    let!(:default_draft) { FactoryBot.create(:education_course_default, :with_pages) }

    it "activates, freezes, and is superseded by the next draft" do
      expect(default_draft.display_name).to eq "Default Draft"
      expect(EducationCourse.active_default).to be_nil

      expect(default_draft.make_active!).to be_truthy
      expect(default_draft.reload).to be_active
      expect(default_draft.display_name).to eq "Default Current"
      expect(EducationCourse.active_default).to eq default_draft

      # Frozen like any live course - editing means a new draft
      expect(default_draft.update(faq_url: "https://example.com/faq")).to be_falsey

      replacement = EducationCourse.draft_for(nil)
      expect(replacement.id).to_not eq default_draft.id
      expect(replacement.make_active!).to be_truthy

      expect(default_draft.reload).to be_archived
      expect(EducationCourse.active_default).to eq replacement
      expect(EducationCourse.defaults.active.count).to eq 1
    end

    it "permits only one default draft" do
      expect { FactoryBot.create(:education_course_default) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "permits only one live default course" do
      default_draft.make_active!

      expect { FactoryBot.create(:education_course_default_active) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#make_active!" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:active) { FactoryBot.create(:education_course_active, :with_pages, organization:) }
    let!(:draft) { FactoryBot.create(:education_course, :with_pages, organization:) }

    it "ends the prior active and makes the draft active" do
      expect(draft.make_active!).to be_truthy

      expect(draft.reload).to be_active
      expect(draft.start_at).to be_present
      expect(active.reload).to be_archived
      expect(active.end_at).to be_present
      expect(organization.education_courses.active.count).to eq(1)
    end

    context "draft without pages" do
      let!(:draft) { FactoryBot.create(:education_course, organization:) }

      it "does not become active" do
        expect(draft.make_active!).to be_falsey
        expect(draft.reload).to be_draft
        expect(active.reload).to be_active
      end
    end

    context "draft with an incomplete page" do
      it "does not become active" do
        # update_column bypasses validation, the way legacy data could
        draft.education_course_pages.first.update_column(:body, "")
        expect(draft.make_active!).to be_falsey
        expect(draft.reload).to be_draft
      end
    end
  end

  describe "#discard_draft!" do
    let(:organization) { FactoryBot.create(:organization) }

    it "removes the draft and its pages" do
      draft = FactoryBot.create(:education_course, :with_pages, organization:)

      expect { expect(draft.discard_draft!).to be_truthy }
        .to change(EducationCourse, :count).by(-1)
        .and change(EducationCoursePage, :count).by(-2)
      expect(EducationCourse.with_deleted.find_by(id: draft.id)).to be_nil
    end

    it "refuses to discard an activated course" do
      active = FactoryBot.create(:education_course_active, :with_pages, organization:)
      expect(active.discard_draft!).to eq false
      expect(active.reload).to be_active
    end
  end

  describe "#reorder_page!" do
    let(:draft) { FactoryBot.create(:education_course) }
    let!(:pages) { FactoryBot.create_list(:education_course_page, 3, education_course: draft) }

    it "moves the page to the position and re-courses listing_order from zero" do
      draft.reorder_page!(pages.last, 0)

      reordered = draft.education_course_pages.reload
      expect(reordered.pluck(:id)).to eq([pages[2].id, pages[0].id, pages[1].id])
      expect(reordered.pluck(:listing_order)).to eq([0, 1, 2])
    end

    it "clamps an out-of-range position to the end" do
      draft.reorder_page!(pages.first, 99)

      expect(draft.education_course_pages.reload.pluck(:id)).to eq([pages[1].id, pages[2].id, pages[0].id])
    end
  end
end
