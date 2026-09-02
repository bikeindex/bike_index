# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::SentToNewOwner::Component, type: :component do
  let(:component) { described_class.new(bike:, owner: true) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }

  it "renders a notice naming the owner who hasn't claimed" do
    render_inline(component)
    expect(page).to have_css('[role="alert"].tw:text-blue-800')
    expect(page).to have_text("You sent this bike to new-owner@example.com")
    expect(page).to have_text("hasn't been claimed yet")
  end

  context "claimed" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "not viewing as the owner" do
    let(:component) { described_class.new(bike:, owner: false) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
