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
end
