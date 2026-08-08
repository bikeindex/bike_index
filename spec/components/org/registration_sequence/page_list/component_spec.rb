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

  it "adds the reorder handles and per-page Edit links" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("[data-controller='sortable'] [data-sortable-target='item']", count: 2)
    expect(page).to have_css("[data-sortable-target='handle']", minimum: 1)
    expect(page).to have_link("Edit", count: 2)
  end

  context "activated sequence" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

    it "is read-only - activation froze it" do
      render_inline(described_class.new(registration_sequence:))

      expect(page).to_not have_link("Edit")
      expect(page).to_not have_css("[data-controller='sortable']")
      expect(page).to_not have_css("[data-sortable-target='item']")
    end
  end

  context "organization-specific page" do
    before { registration_sequence.registration_sequence_pages.first.update!(organization_specific: true) }

    it "badges it with the organization's name" do
      render_inline(described_class.new(registration_sequence:))

      expect(page).to have_content("Brakebills")
    end

    context "on the template" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_template, :with_pages) }

      it "badges it with the template, which has no organization" do
        # Only admin edits the template - there's no organization to route it through
        render_inline(described_class.new(registration_sequence:, admin: true))

        expect(page).to have_content("Template")
      end
    end
  end

  context "admin" do
    it "links each page and reorders through the admin routes" do
      render_inline(described_class.new(registration_sequence:, admin: true))
      first_page = registration_sequence.registration_sequence_pages.first

      expect(page).to have_link("Edit", href: "/admin/registration_sequence_pages/#{first_page.id}/edit")
      expect(page).to have_css("[data-sortable-target='item'][data-url='/admin/registration_sequence_pages/#{first_page.id}']")
    end
  end
end
