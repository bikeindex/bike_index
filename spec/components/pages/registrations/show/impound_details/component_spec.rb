# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::ImpoundDetails::Component, type: :component do
  let(:component) { described_class.new(bike:) }

  context "org-impounded bike" do
    let(:bike) { FactoryBot.create(:impound_record, :with_organization).bike.reload }

    it "renders the impound card with the impounded-at date" do
      render_inline(component)
      expect(page).to have_text("Impound details")
      expect(page).to have_text("Impounded at")
    end
  end

  context "found bike" do
    let(:bike) { FactoryBot.create(:bike, :impounded).reload }

    it "renders the found card with the found-at date" do
      render_inline(component)
      expect(page).to have_text("Found details")
      expect(page).to have_text("Found at")
    end
  end

  context "non-impounded bike" do
    let(:bike) { FactoryBot.create(:bike) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
