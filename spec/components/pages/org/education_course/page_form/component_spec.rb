# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::EducationCourse::PageForm::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:education_course) { FactoryBot.create(:education_course, organization:) }
  let(:organization_id) { organization.to_param }

  context "an organization's draft" do
    it "posts a new page to the course, without a preview or a delete" do
      render_inline(described_class.new(page: education_course.education_course_pages.new))

      expect(page).to have_css("h1", text: "Add page")
      expect(page).to have_css("form[action='/o/#{organization_id}/education_courses/#{education_course.id}/pages']")
      expect(page).to_not have_content("Preview")
      expect(page).to_not have_link("Delete page")
    end

    it "patches an existing page, and previews it as a registrant sees it" do
      education_course_page = FactoryBot.create(:education_course_page, education_course:, title: "Batteries")
      render_inline(described_class.new(page: education_course_page))

      expect(page).to have_css("form[action='/o/#{organization_id}/education_course_pages/#{education_course_page.id}']")
      expect(page).to have_link("Delete page", href: "/o/#{organization_id}/education_course_pages/#{education_course_page.id}")
      expect(page).to have_content("Preview")
      expect(page).to have_content("Batteries")
    end
  end

  context "admin" do
    let(:education_course) { FactoryBot.create(:education_course_default) }

    it "posts and patches through the admin routes" do
      render_inline(described_class.new(page: education_course.education_course_pages.new, admin: true))

      expect(page).to have_css("form[action='/admin/education_courses/#{education_course.id}/pages']")
      expect(page).to have_link("Back to course overview", href: "/admin/education_courses/#{education_course.id}/edit")
      # Admin's header is the h1
      expect(page).to have_css("h2", text: "Add page")
      expect(page).to_not have_css("h1")
    end
  end
end
