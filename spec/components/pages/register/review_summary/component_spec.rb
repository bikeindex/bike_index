# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::ReviewSummary::Component, type: :component do
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, :with_pages) }
  let(:pages) { registration_sequence.registration_sequence_pages.to_a }

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
