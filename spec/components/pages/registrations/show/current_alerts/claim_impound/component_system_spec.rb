# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::ClaimImpound::Component, :js, type: :system do
  # One preview per state, each rendering the card on the page it sits in
  let(:preview_path) { "/rails/view_components/pages/registrations/show/wrapper/claim_impound/component" }
  let!(:impound_record) { FactoryBot.create(:impound_record) }
  let!(:stolen_bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed) }

  it "offers each viewer without a claim what they can do, and holds the form open in the URL" do
    visit "#{preview_path}/signed_out"

    expect(page).to have_link("Claim found bike", href: /session\/new/)

    visit "#{preview_path}/without_stolen_registration"

    expect(page).to have_content("You need a stolen bike registered")
    expect(page).to have_link("add a stolen bike")
    expect(page).to have_no_button("Claim found bike")
    expect_axe_clean

    visit "#{preview_path}/with_stolen_registration"

    expect(page).to have_button("Claim found bike")
    # The form is behind the collapse until it's asked for
    expect(page).to have_no_button("Open claim")
    expect(page).to have_no_select("impound_claim[stolen_record_id]")
    expect_axe_clean

    click_button "Claim found bike"

    expect(page).to have_button("Open claim")
    expect(page).to have_select("Select your stolen bike matching this impounded bike", options: ["Choose stolen bike", stolen_bike.title_string])
    expect(find_button("Claim found bike")["aria-expanded"]).to eq "true"
    # impound_claims#create redirects back with this param, so the form is open on arrival
    expect(page).to have_current_path(/contact_owner=1/, url: true)
    expect_axe_clean # the revealed form is new markup

    visit page.current_url

    expect(page).to have_button("Open claim")

    click_button "Claim found bike"

    expect(page).to have_no_button("Open claim")
    expect(page).to have_no_current_path(/contact_owner/, url: true)
  end

  # One claim, seen from both sides. The bike it was submitted with is normally the
  # claimant's own, and the card is never shown to an owner - so reaching that side of it
  # needs one registered by somebody else
  context "the viewer opened a claim" do
    let(:submitting) { FactoryBot.create(:bike, :with_ownership, owner_email: "someone-else@example.com") }
    let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, impound_record:, bike: submitting) }

    it "offers the message form, points back from the submitting bike, then carries the outcome" do
      visit "#{preview_path}/unsubmitted"

      # Required in the browser, so an empty box won't save - though nothing server-side
      # turns an empty claim away
      expect(page).to have_field("Verify your ownership", type: "textarea", valid: false)
      expect(page).to have_button("Save message")

      # Submitting is the same form, so the required box blocks it too - the page stays put
      click_button "Submit claim"

      expect(page).to have_current_path("#{preview_path}/unsubmitted")

      fill_in "Verify your ownership", with: "it still has my sticker under the seat"

      expect(page).to have_field("Verify your ownership", valid: true)
      # The card is the claim now, rather than an invitation to open one
      expect(page).to have_no_button("Claim found bike")
      expect_axe_clean

      # The bike the claim was submitted with points at the impound rather than
      # offering a claim of its own
      visit "#{preview_path}/submitted_with_this_bike"

      expect(page).to have_content("You have a pending claim with this bike")
      expect_axe_clean

      # The kind reads off the impound record, so match the part that doesn't vary
      click_link "view the claimed"

      expect(page).to have_current_path(registration_path(impound_claim.bike_claimed))

      impound_claim.update(status: "submitting")
      visit "#{preview_path}/submitted"

      expect(page).to have_content("This claim was submitted")
      expect(page).to have_no_button("Save message")
      expect(page).to have_no_button("Submit claim")

      impound_claim.update(status: "approved")
      visit "#{preview_path}/approved"

      expect(page).to have_content("Your claim was approved")
    end
  end
end
