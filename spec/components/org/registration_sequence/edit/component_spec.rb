# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSequence::Edit::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

  it "renders the page list with Add page and per-page Edit links" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_text("Add page")
    expect(page).to have_css("[data-controller='sortable'] [data-sortable-target='item']", minimum: 1)
    expect(page).to have_link("Edit")
  end

  it "renders a drag grip on each row (SortableJS limits dragging to the handle)" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("[data-sortable-target='item'] [data-sortable-target='handle']", minimum: 1)
  end

  it "puts each page's body in a collapsed disclosure toggled by a chevron" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("button[data-action~='disclosure#toggle'] [data-disclosure-target='chevron']", minimum: 1)
    expect(page).to have_css("[data-disclosure-target='content'][class*='hidden'] li", minimum: 1)
  end
end
