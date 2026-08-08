# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::RegistrationSequence::Header::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
  let(:admin_url) { "/admin/registration_sequences/#{registration_sequence.id}" }

  it "names the organization and status, and switches to the preview" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_content("Editing Brakebills Draft registration sequence", normalize_ws: true)
    expect(page).to have_link("Preview", href: admin_url)
    expect(page).to have_link("View in organization", href: "/o/#{organization.to_param}/registration_sequences/#{registration_sequence.id}")
  end

  context "previewing" do
    it "switches back to the editor" do
      render_inline(described_class.new(registration_sequence:, previewing: true))

      expect(page).to have_content("Previewing Brakebills Draft registration sequence", normalize_ws: true)
      expect(page).to have_link("Edit", href: "#{admin_url}/edit")
    end
  end

  context "activated sequence" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization:) }

    it "views rather than edits - activation freezes it" do
      render_inline(described_class.new(registration_sequence:))
      expect(page).to have_content("Viewing Brakebills Current registration sequence", normalize_ws: true)

      render_inline(described_class.new(registration_sequence:, previewing: true))
      expect(page).to have_link("View", href: "#{admin_url}/edit")
    end
  end

  context "template" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_template) }

    it "names the template once, with no organization to view it in" do
      render_inline(described_class.new(registration_sequence:))

      expect(page).to have_content("Editing Template registration sequence", normalize_ws: true)
      expect(page).to_not have_link("View in organization")
    end
  end
end
