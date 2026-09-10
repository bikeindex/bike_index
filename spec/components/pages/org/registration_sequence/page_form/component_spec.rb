# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::RegistrationSequence::PageForm::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
  let(:organization_id) { organization.to_param }

  context "an organization's draft" do
    it "posts a new page to the sequence, without a preview or a delete" do
      render_inline(described_class.new(page: registration_sequence.registration_sequence_pages.new))

      expect(page).to have_css("h1", text: "Add page")
      expect(page).to have_css("form[action='/o/#{organization_id}/registration_sequences/#{registration_sequence.id}/pages']")
      expect(page).to_not have_content("Preview")
      expect(page).to_not have_link("Delete page")
    end

    it "patches an existing page, and previews it as a registrant sees it" do
      registration_sequence_page = FactoryBot.create(:registration_sequence_page, registration_sequence:, title: "Batteries")
      render_inline(described_class.new(page: registration_sequence_page))

      expect(page).to have_css("form[action='/o/#{organization_id}/registration_sequence_pages/#{registration_sequence_page.id}']")
      expect(page).to have_link("Delete page", href: "/o/#{organization_id}/registration_sequence_pages/#{registration_sequence_page.id}")
      expect(page).to have_content("Preview")
      expect(page).to have_content("Batteries")
    end
  end

  context "admin" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_template) }

    it "posts and patches through the admin routes" do
      render_inline(described_class.new(page: registration_sequence.registration_sequence_pages.new, admin: true))

      expect(page).to have_css("form[action='/admin/registration_sequences/#{registration_sequence.id}/pages']")
      expect(page).to have_link("Back to sequence overview", href: "/admin/registration_sequences/#{registration_sequence.id}/edit")
      # Admin's header is the h1
      expect(page).to have_css("h2", text: "Add page")
      expect(page).to_not have_css("h1")
    end
  end
end
