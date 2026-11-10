# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Parts::ReviewSummary::Component, type: :component do
  let(:education_course) { FactoryBot.create(:education_course, :with_pages) }
  let(:pages) { education_course.education_course_pages.to_a }

  it "lists every page, without links when there's nowhere to send them" do
    render_inline(described_class.new(pages:))

    expect(page).to have_content("You're almost done")
    expect(page).to have_content("A quick review of everything you acknowledged.")
    expect(page).to have_no_content("Tap Review")
    expect(page).to have_css("svg", minimum: 2) # the green check per page
    expect(page).to have_no_link("Review")
  end

  it "links each page back when given a path" do
    render_inline(described_class.new(pages:, page_path: ->(index) { "/back/to/#{index}" }))

    expect(page).to have_content("Tap Review to revisit a protocol")
    expect(page).to have_link("Review", href: "/back/to/0")
    expect(page).to have_link("Review", href: "/back/to/1")
  end
end
