# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::ClaimImpound::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, owner: false) }
  let(:bike) { FactoryBot.create(:bike_organized, :impounded).reload }

  context "impounded bike, logged out" do
    let(:current_user) { nil }

    it "shows the claim card with a sign-in link" do
      render_inline(component)
      expect(page).to have_text("Does this look like your bike?")
      expect(page).to have_css("a[href*='session/new']", text: "Claim impounded bike")
    end
  end

  context "impounded bike, viewer owns a stolen bike" do
    let(:stolen_bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }
    let(:current_user) { stolen_bike.reload.user }

    it "reveals a form to pick a stolen bike and open the claim" do
      render_inline(component)
      expect(page).to have_button("Claim impounded bike")
      expect(page).to have_css("form[action='/impound_claims'] select[name='impound_claim[stolen_record_id]']", visible: :all)
      expect(page).to have_button("Open claim")
    end
  end

  context "impounded bike, viewer has no stolen bike" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "prompts them to register a stolen bike" do
      render_inline(component)
      expect(page).to have_text("need a stolen bike")
      expect(page).to have_link("add a stolen bike")
    end
  end

  context "non-impounded bike" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
