# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::RegistrationSequence::Edit::Component, type: :component do
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

  it "links to the full preview walk-through" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_link("Preview")
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

  context "admin" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_template, :with_pages) }

    it "counts the pages and links Add page through the admin routes" do
      render_inline(described_class.new(registration_sequence:, admin: true))

      # Admin renders its own header, which names the sequence
      expect(page).to have_content("2 pages")
      expect(page).to_not have_content("registration sequence")
      expect(page).to have_link("Add page", href: "/admin/registration_sequences/#{registration_sequence.id}/pages/new")
      expect(page).to have_css("form[action='/admin/registration_sequences/#{registration_sequence.id}']")
      # Admin's header switches between the screens, so there's no big Preview button
      expect(page).to_not have_link("Preview")
    end

    context "activated sequence" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

      it "renders read-only - acknowledgments reference what it says" do
        render_inline(described_class.new(registration_sequence:, admin: true))

        expect(page).to_not have_link("Add page")
        expect(page).to_not have_field("registration_sequence[faq_url]")
        expect(page).to_not have_css("[data-controller='sortable']")
        expect(page).to_not have_link("Edit")
      end
    end
  end

  it "puts each page's body in an expanded disclosure toggled by a chevron" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("button[data-action~='ui--collapse#toggle'] [data-ui--collapse-target='chevron']", minimum: 1)
    # Starts open - the content is visible, not hidden
    expect(page).to have_css("[data-ui--collapse-target='content']:not([class*='hidden']) li", minimum: 1)
  end
end
