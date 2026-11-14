# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::EducationCourse::DiscardDraft::Component, type: :component do
  let(:education_course) { FactoryBot.create(:education_course) }

  it "deletes the draft, behind a confirm" do
    rendered = render_inline(described_class.new(education_course:))

    expect(page).to have_css("a[href='/admin/education_courses/#{education_course.id}'][data-turbo-method='delete']",
      text: "Discard draft")
    expect(rendered.to_html).to include("confirm('Discard this draft and its pages?")
  end

  it "renders for the default course's draft too" do
    render_inline(described_class.new(education_course: FactoryBot.create(:education_course_default)))

    expect(page).to have_link("Discard draft")
  end

  context "activated course" do
    let(:education_course) { FactoryBot.create(:education_course_active) }

    it "renders nothing - there's no draft to throw away" do
      rendered = render_inline(described_class.new(education_course:))

      expect(rendered.to_html).to be_blank
    end
  end
end
