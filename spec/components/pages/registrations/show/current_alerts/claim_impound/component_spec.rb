# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::ClaimImpound::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, owner: false) }
  # An e-scooter, so every string has to name the registration's cycle type
  let(:bike) { FactoryBot.create(:impound_record, :with_organization, bike: e_scooter).bike.reload }
  let(:e_scooter) { FactoryBot.create(:bike, cycle_type: "e-scooter") }

  context "impounded e-scooter, logged out" do
    let(:current_user) { nil }

    it "shows the claim card with a sign-in link" do
      render_inline(component)
      expect(page).to have_text("Does this look like your e-scooter?")
      expect(page).to have_css("a[href*='session/new']", text: "Claim impounded e-scooter")
    end
  end

  context "impounded e-scooter, viewer owns a stolen bike" do
    let(:stolen_bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }
    let(:current_user) { stolen_bike.reload.user }

    it "reveals a form to pick a stolen bike and open the claim" do
      render_inline(component)
      expect(page).to have_button("Claim impounded e-scooter")
      expect(page).to have_css("form[action='/impound_claims'] select[name='impound_claim[stolen_record_id]']", visible: :all)
      expect(page).to have_text("Select the stolen e-scooter you own")
      expect(page).to have_css("option", text: "Choose stolen e-scooter", visible: :all)
      expect(page).to have_button("Open claim")
    end
  end

  context "impounded e-scooter, viewer has no stolen bike" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "prompts them into the registration flow, with the status set" do
      render_inline(component)
      expect(page).to have_text("You need a stolen e-scooter registered")
      expect(page).to have_link("add a stolen e-scooter", href: "/register/new?status=status_stolen")
    end
  end

  context "found e-scooter" do
    let(:bike) { FactoryBot.create(:bike, :impounded, cycle_type: "e-scooter").reload }
    let(:current_user) { nil }

    it "labels the button for a found registration" do
      render_inline(component)
      expect(page).to have_text("Claim found e-scooter")
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
      form = "form[action='/impound_claims/#{impound_claim.id}']"
      expect(page).to have_css(form, count: 1)
      expect(page).to have_css("#{form} textarea[name='impound_claim[message]']")
      expect(page).to have_button("Save message")
      # Submitting is the same form, so it carries the message rather than dropping it
      expect(page).to have_css("#{form} button[name='impound_claim[status]'][value='submitting']", text: "Submit claim")
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

  # The alerts render in the organization's panel too, and its staff aren't being asked
  # whether the bike is theirs
  context "viewed through an organization" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:component) { described_class.new(bike:, current_user:, owner: false, organization:) }
    let(:current_user) { FactoryBot.create(:organization_admin, organization:) }

    it "does not render" do
      expect(BikeServices::Displayer.display_impound_claim?(bike, current_user)).to be_truthy
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  # Each scenario resolves its own viewer, so one it can't find says so rather than
  # previewing whichever state the viewer it fell back to lands on
  describe "Wrapper::ClaimImpound::ComponentPreview" do
    let(:preview) { Pages::Registrations::Show::Wrapper::ClaimImpound::ComponentPreview.new }
    let(:finder) { FactoryBot.create(:user_confirmed) }
    let!(:impound_record) { FactoryBot.create(:impound_record, user: finder) }

    def notice_text(rendered) = rendered[:component]&.instance_variable_get(:@text)

    it "says so when nobody holds a stolen registration to claim with" do
      expect(notice_text(preview.with_stolen_registration)).to match("no viewer")
    end

    context "the only stolen registration is the finder's" do
      let!(:stolen_bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed, user: finder) }

      def preview_viewer(rendered) = rendered.dig(:locals, :component).instance_variable_get(:@current_user)

      it "previews as the viewer each scenario is about" do
        expect(preview_viewer(preview.with_stolen_registration)).to eq finder

        without = preview_viewer(preview.without_stolen_registration)

        expect(without).to_not eq finder
        expect(without.bikes.status_stolen).to be_empty
      end
    end
  end
end
