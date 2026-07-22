# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::ImpoundDetails::Component, type: :component do
  let(:component) { described_class.new(bike:) }

  context "impounded bike" do
    let(:bike) { FactoryBot.create(:bike_organized, :impounded).reload }

    it "renders the impound card with the impounded-at date" do
      render_inline(component)
      expect(page).to have_text("Impound details")
      expect(page).to have_text("Impounded at")
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
