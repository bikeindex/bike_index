# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSequence::Edit::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

  it "renders the page list with Add page and per-page Edit links" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_link("Add page")
    expect(page).to have_css("[data-controller='sortable'] [data-sortable-target='item']", minimum: 1)
    expect(page).to have_link("Edit")
  end

  it "renders a drag grip on each row (SortableJS limits dragging to the handle)" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("[data-sortable-target='item'] [data-sortable-target='handle']", minimum: 1)
  end

  it "renders the settings shared by every page" do
    registration_sequence.update!(faq_url: "https://example.com/faq")
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_field("registration_sequence[faq_url]", with: "https://example.com/faq")
    # A blank acknowledgment falls back to the default, which the placeholder shows
    expect(page).to have_field("registration_sequence[acknowledgment_text]", with: "",
      placeholder: RegistrationSequence::DEFAULT_ACKNOWLEDGMENT_TEXT)
  end

  it "badges an organization-specific page with the organization's name" do
    render_inline(described_class.new(registration_sequence:))
    expect(page).to_not have_content(organization.short_name)

    registration_sequence.registration_sequence_pages.first.update!(organization_specific: true)
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_content(organization.short_name)
  end

  it "puts each page's body in a collapsed disclosure toggled by a chevron" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("button[data-action~='ui--collapse#toggle'] [data-ui--collapse-target='chevron']", minimum: 1)
    expect(page).to have_css("[data-ui--collapse-target='content'][class*='hidden'] li", minimum: 1)
  end

  it "previews the pages as registrants see them" do
    registration_sequence.registration_sequence_pages.first.update!(heading: "Electric vehicle detected")
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_content("Preview")
    # The page list shows the title; only the preview renders heading_text
    expect(page).to have_css("h3", text: "Electric vehicle detected")
    # Rules render as read-only checkboxes, closing with the final acknowledgment
    expect(page).to have_css("input[type=checkbox][disabled]", minimum: 3)
    expect(page).to have_content("I, registrant's name,")
  end
end
