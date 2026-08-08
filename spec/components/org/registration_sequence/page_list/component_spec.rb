# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSequence::PageList::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

  it "lists each page with its rules expanded in a toggleable disclosure" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("[data-controller='ui--collapse']", count: 2)
    # Starts open - the content is visible, not hidden
    expect(page).to have_css("[data-ui--collapse-target='content']:not([class*='hidden']) li", minimum: 1)
  end

  it "is read-only by default - the active version is frozen" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to_not have_link("Edit")
    expect(page).to_not have_css("[data-controller='sortable']")
    expect(page).to_not have_css("[data-sortable-target='item']")
  end

  context "editable" do
    it "adds the reorder handles and per-page Edit links" do
      render_inline(described_class.new(registration_sequence:, editable: true))

      expect(page).to have_css("[data-controller='sortable'] [data-sortable-target='item']", count: 2)
      expect(page).to have_css("[data-sortable-target='handle']", minimum: 1)
      expect(page).to have_link("Edit", count: 2)
    end
  end

  context "organization-specific page" do
    before { registration_sequence.registration_sequence_pages.first.update!(organization_specific: true) }

    it "badges it with the organization's name" do
      render_inline(described_class.new(registration_sequence:))

      expect(page).to have_content("Brakebills")
    end
  end
end
