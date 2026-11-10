# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::EducationCourse::PageList::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:education_course) { FactoryBot.create(:education_course, :with_pages, organization:) }

  it "lists each page with its rules expanded in a toggleable disclosure" do
    render_inline(described_class.new(education_course:))

    expect(page).to have_css("[data-controller='ui--collapse']", count: 2)
    # Starts open - the content is visible, not hidden
    expect(page).to have_css("[data-ui--collapse-target='content']:not([class*='hidden']) li", minimum: 1)
  end

  it "adds the reorder handles and per-page Edit links" do
    render_inline(described_class.new(education_course:))

    expect(page).to have_css("[data-controller='sortable'] [data-sortable-target='item']", count: 2)
    expect(page).to have_css("[data-sortable-target='handle']", minimum: 1)
    expect(page).to have_link("Edit", count: 2)
  end

  context "activated sequence" do
    let(:education_course) do
      FactoryBot.create(:education_course_active, :with_pages, organization:,
        faq_url: "https://example.com/faq", acknowledgment_text: "agree to the rules above")
    end

    it "is read-only - activation froze it" do
      render_inline(described_class.new(education_course:))

      expect(page).to_not have_link("Edit")
      expect(page).to_not have_css("[data-controller='sortable']")
      expect(page).to_not have_css("[data-sortable-target='item']")
    end

    it "ends on the acknowledgment registrants agree to, linking the FAQ" do
      render_inline(described_class.new(education_course:))

      expect(page).to have_css("h3", text: "Final acknowledgment")
      expect(page).to have_link("FAQ link", href: "https://example.com/faq")
      expect(page).to have_content("agree to the rules above")
    end

    context "without a faq_url" do
      let(:education_course) { FactoryBot.create(:education_course_active, :with_pages, organization:) }

      it "falls back to the default acknowledgment, with no link to show" do
        render_inline(described_class.new(education_course:))

        expect(page).to have_css("h3", text: "Final acknowledgment")
        expect(page).to have_content(EducationCourse::DEFAULT_ACKNOWLEDGMENT_TEXT)
        expect(page).to_not have_link("FAQ link")
      end
    end
  end

  it "leaves the acknowledgment to the editor's own field when editable" do
    render_inline(described_class.new(education_course:))

    expect(page).to_not have_css("h3", text: "Final acknowledgment")
  end

  context "organization-specific page" do
    before { education_course.education_course_pages.first.update!(organization_specific: true) }

    it "badges it with the organization's name" do
      render_inline(described_class.new(education_course:))

      expect(page).to have_content("Brakebills")
    end

    context "on the template" do
      let(:education_course) { FactoryBot.create(:education_course_template, :with_pages) }

      it "badges it with the template, which has no organization" do
        # Only admin edits the template - there's no organization to route it through
        render_inline(described_class.new(education_course:, admin: true))

        expect(page).to have_content("Template")
      end
    end
  end

  context "admin" do
    it "links each page and reorders through the admin routes" do
      render_inline(described_class.new(education_course:, admin: true))
      first_page = education_course.education_course_pages.first

      expect(page).to have_link("Edit", href: "/admin/education_course_pages/#{first_page.id}/edit")
      expect(page).to have_css("[data-sortable-target='item'][data-url='/admin/education_course_pages/#{first_page.id}']")
    end
  end
end
