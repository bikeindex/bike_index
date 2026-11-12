# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::EducationCourse::Edit::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:education_course) { FactoryBot.create(:education_course, :with_pages, organization:) }

  it "renders the page list with Add page and per-page Edit links" do
    render_inline(described_class.new(education_course:))

    expect(page).to have_link("Add page")
    expect(page).to have_css("[data-controller='sortable'] [data-sortable-target='item']", minimum: 1)
    expect(page).to have_link("Edit")
  end

  it "renders a drag grip on each row (SortableJS limits dragging to the handle)" do
    render_inline(described_class.new(education_course:))

    expect(page).to have_css("[data-sortable-target='item'] [data-sortable-target='handle']", minimum: 1)
  end

  it "links to the full preview walk-through" do
    render_inline(described_class.new(education_course:))

    expect(page).to have_link("Preview")
  end

  it "renders the settings shared by every page" do
    education_course.update!(faq_url: "https://example.com/faq")
    render_inline(described_class.new(education_course:))

    expect(page).to have_field("education_course[faq_url]", with: "https://example.com/faq")
    # A blank acknowledgment falls back to the default, which the placeholder shows
    expect(page).to have_field("education_course[acknowledgment_text]", with: "",
      placeholder: EducationCourse::DEFAULT_ACKNOWLEDGMENT_TEXT)
  end

  it "badges an organization-specific page with the organization's name" do
    render_inline(described_class.new(education_course:))
    expect(page).to_not have_content(organization.short_name)

    education_course.education_course_pages.first.update!(organization_specific: true)
    render_inline(described_class.new(education_course:))

    expect(page).to have_content(organization.short_name)
  end

  context "admin" do
    let(:education_course) { FactoryBot.create(:education_course_default, :with_pages) }

    it "counts the pages and links Add page through the admin routes" do
      render_inline(described_class.new(education_course:, admin: true))

      # Admin renders its own header, which names the course
      expect(page).to have_content("2 pages")
      expect(page).to_not have_content("education course")
      expect(page).to have_link("Add page", href: "/admin/education_courses/#{education_course.id}/pages/new")
      expect(page).to have_css("form[action='/admin/education_courses/#{education_course.id}']")
      # Admin's header switches between the screens, so there's no big Preview button
      expect(page).to_not have_link("Preview")
    end

    context "activated course" do
      let(:education_course) { FactoryBot.create(:education_course_active, :with_pages, organization:) }

      it "renders read-only - acknowledgments reference what it says" do
        render_inline(described_class.new(education_course:, admin: true))

        expect(page).to_not have_link("Add page")
        expect(page).to_not have_field("education_course[faq_url]")
        expect(page).to_not have_css("[data-controller='sortable']")
        expect(page).to_not have_link("Edit")
      end
    end
  end

  it "puts each page's body in an expanded disclosure toggled by a chevron" do
    render_inline(described_class.new(education_course:))

    expect(page).to have_css("button[data-action~='ui--collapse#toggle'] [data-ui--collapse-target='chevron']", minimum: 1)
    # Starts open - the content is visible, not hidden
    expect(page).to have_css("[data-ui--collapse-target='content']:not([class*='hidden']) li", minimum: 1)
  end
end
