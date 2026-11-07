# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::EducationCourse::PageEdit::Component, type: :component do
  let(:page) { EducationCoursePage.new(body: "<ul><li>first bullet</li></ul>") }

  def rendered_component(page)
    render_in_view_context do
      form_for page, url: "#", method: :patch do |f|
        render(Pages::Org::EducationCourse::PageEdit::Component.new(form_builder: f))
      end
    end
  end

  let(:component) { rendered_component(page) }

  it "renders the image field, a hidden body field, and a Lexxy editor per bullet" do
    expect(component).to have_field("education_course_page_image")
    expect(component).to have_css("input[type=hidden][name='education_course_page[body]']", visible: :all)
    expect(component).to have_css("lexxy-editor[name='bullet[0][content]']", visible: :all)
    expect(component).to_not have_field("education_course_page_listing_order")
    expect(component).to_not have_field("education_course_page_organization_specific")
  end

  context "on an organization's draft" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let(:education_course) { FactoryBot.create(:education_course, organization:) }
    let(:page) { FactoryBot.create(:education_course_page, education_course:) }

    it "offers the organization-specific toggle, named after the organization" do
      expect(component).to have_field("education_course_page_organization_specific")
      expect(component).to have_content("Specific to Brakebills")
    end
  end

  context "on the template" do
    let(:education_course) { FactoryBot.create(:education_course_template) }
    let(:page) { FactoryBot.create(:education_course_page, education_course:) }

    it "names the toggle for the template, which has no organization" do
      expect(component).to have_field("education_course_page_organization_specific")
      expect(component).to have_content("Specific to Template")
    end
  end
end
