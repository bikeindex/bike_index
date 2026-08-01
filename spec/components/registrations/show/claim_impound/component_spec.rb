# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::ClaimImpound::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, owner: false) }
  let(:bike) { FactoryBot.create(:impound_record, :with_organization).bike.reload }

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

  context "found bike" do
    let(:bike) { FactoryBot.create(:bike, :impounded).reload }
    let(:current_user) { nil }

    it "labels the button for a found bike" do
      render_inline(component)
      expect(page).to have_text("Claim found bike")
    end
  end

  context "viewer already opened a claim" do
    let(:impound_record) { FactoryBot.create(:impound_record, :with_organization) }
    let(:bike) { impound_record.bike.reload }
    let(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, impound_record:, user: current_user) }
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    before { impound_claim }

    it "shows the claim's message form rather than another open-claim form" do
      render_inline(component)
      expect(page).to have_text("Your claim")
      expect(page).to_not have_text("Does this look like your bike?")
      expect(page).to_not have_button("Open claim")
      expect(page).to have_css("form[action='/impound_claims/#{impound_claim.id}'] textarea[name='impound_claim[message]']")
      expect(page).to have_button("Save message")
      expect(page).to have_button("Submit claim")
    end

    context "claim submitted" do
      before { impound_claim.update(status: "submitting") }

      it "shows when it was submitted, without the editing forms" do
        expect(impound_claim.reload.submitted?).to be_truthy
        render_inline(component)
        expect(page).to have_text("This claim was submitted")
        expect(page).to_not have_button("Save message")
        expect(page).to_not have_button("Submit claim")
      end

      context "claim approved" do
        before { impound_claim.update(status: "approved") }

        it "says the claim was approved" do
          render_inline(component)
          expect(page).to have_text("Your claim was approved")
        end
      end
    end

    context "claim denied" do
      before { impound_claim.update(status: "denied") }

      it "offers the open-claim form again" do
        expect(impound_claim.reload.rejected?).to be_truthy
        render_inline(component)
        expect(page).to have_text("Does this look like your bike?")
        expect(page).to_not have_text("Your claim")
      end
    end
  end

  # display_impound_claim? matches the bike a claim was submitted *with*, which has
  # no impound_record of its own
  context "viewing the stolen bike the claim was submitted with" do
    let(:stolen_record) { FactoryBot.create(:stolen_record, bike: FactoryBot.create(:bike, :with_ownership)) }
    let(:bike) { stolen_record.bike.reload }
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    let!(:impound_claim) { FactoryBot.create(:impound_claim, stolen_record:, user: current_user) }

    it "points at the claimed bike instead of rendering a claim form" do
      expect(impound_claim.reload.bike_submitting_id).to eq bike.id
      expect(bike.owner).to_not eq current_user
      render_inline(component)
      expect(page).to have_text("You have a pending claim with this bike")
      expect(page).to have_link(href: "/registrations/#{impound_claim.bike_claimed_id}")
      expect(page).to_not have_button("Open claim")
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
