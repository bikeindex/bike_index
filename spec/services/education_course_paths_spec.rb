require "rails_helper"

RSpec.describe EducationCoursePaths do
  let(:organization) { FactoryBot.create(:organization) }
  let(:education_course) { FactoryBot.create(:education_course, organization:) }
  let(:education_course_page) { FactoryBot.create(:education_course_page, education_course:) }

  context "an organization's course" do
    let(:base_url) { "/o/#{organization.to_param}" }

    it "builds the organization's routes" do
      expect(described_class.index(education_course)).to eq "#{base_url}/education_courses"
      expect(described_class.index(education_course, admin: true))
        .to eq "/admin/organizations/#{organization.to_param}?active_tab=education_courses"
      expect(described_class.course(education_course)).to eq "#{base_url}/education_courses/#{education_course.id}"
      expect(described_class.course(education_course, page: 2)).to eq "#{base_url}/education_courses/#{education_course.id}?page=2"
      # The organization's member path is its preview; admin's is a screen of its own
      expect(described_class.preview(education_course)).to eq "#{base_url}/education_courses/#{education_course.id}"
      expect(described_class.edit(education_course)).to eq "#{base_url}/education_courses/#{education_course.id}/edit"
      expect(described_class.new_page(education_course)).to eq "#{base_url}/education_courses/#{education_course.id}/pages/new"
      expect(described_class.pages(education_course)).to eq "#{base_url}/education_courses/#{education_course.id}/pages"
      expect(described_class.page(education_course_page)).to eq "#{base_url}/education_course_pages/#{education_course_page.id}"
      expect(described_class.edit_page(education_course_page)).to eq "#{base_url}/education_course_pages/#{education_course_page.id}/edit"
    end
  end

  context "admin" do
    let(:education_course) { FactoryBot.create(:education_course_template) }

    it "builds the admin routes, which don't scope to an organization" do
      expect(described_class.index(education_course, admin: true)).to eq "/admin/education_courses"
      expect(described_class.course(education_course, admin: true)).to eq "/admin/education_courses/#{education_course.id}"
      expect(described_class.course(education_course, page: 2, admin: true)).to eq "/admin/education_courses/#{education_course.id}?page=2"
      expect(described_class.preview(education_course, admin: true)).to eq "/admin/education_courses/#{education_course.id}/preview"
      expect(described_class.preview(education_course, page: 2, admin: true)).to eq "/admin/education_courses/#{education_course.id}/preview?page=2"
      expect(described_class.edit(education_course, admin: true)).to eq "/admin/education_courses/#{education_course.id}/edit"
      expect(described_class.new_page(education_course, admin: true)).to eq "/admin/education_courses/#{education_course.id}/pages/new"
      expect(described_class.pages(education_course, admin: true)).to eq "/admin/education_courses/#{education_course.id}/pages"
      expect(described_class.page(education_course_page, admin: true)).to eq "/admin/education_course_pages/#{education_course_page.id}"
      expect(described_class.edit_page(education_course_page, admin: true)).to eq "/admin/education_course_pages/#{education_course_page.id}/edit"
    end
  end

  describe "preview_exit" do
    it "returns admin to the read-only screen, which every course has" do
      expect(described_class.preview_exit(education_course, admin: true))
        .to eq "/admin/education_courses/#{education_course.id}"
    end

    it "returns to the editor" do
      expect(described_class.preview_exit(education_course))
        .to eq "/o/#{organization.to_param}/education_courses/#{education_course.id}/edit"
    end

    context "activated course" do
      let(:education_course) { FactoryBot.create(:education_course_active, organization:) }

      it "returns to the organization's list - it has no editor for a frozen course" do
        expect(described_class.preview_exit(education_course))
          .to eq "/o/#{organization.to_param}/education_courses"
      end
    end
  end
end
