# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::CurrentAlerts::ClaimImpound::Component, :js, type: :system do
  # One preview per state, each rendering the card on the page it sits in
  let(:preview_path) { "/rails/view_components/registrations/show/wrapper/claim_impound/component" }
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
    expect(page).to have_select("Select the stolen bike you own", options: ["Choose stolen bike", stolen_bike.title_string])
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

  context "the viewer opened a claim of their own" do
    let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, impound_record:) }

    it "offers the message form, then carries the outcome once it's answered" do
      visit "#{preview_path}/unsubmitted"

      expect(page).to have_field("Verify your ownership")
      expect(page).to have_button("Save message")
      expect(page).to have_button("Submit claim")
      # The card is the claim now, rather than an invitation to open one
      expect(page).to have_no_button("Claim found bike")
      expect_axe_clean

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

  # The submitting bike is normally the claimant's own, and the card is never shown to an
  # owner - so reaching this state needs one registered by somebody else
  context "viewing the stolen bike a claim was submitted with" do
    let(:submitting) { FactoryBot.create(:bike, :with_ownership, owner_email: "someone-else@example.com") }
    let(:stolen_record) { FactoryBot.create(:stolen_record, bike: submitting) }
    let!(:impound_claim) { FactoryBot.create(:impound_claim, stolen_record:, user: FactoryBot.create(:user_confirmed)) }

    it "links through to the bike it claims" do
      visit "#{preview_path}/submitted_with_this_bike"

      expect(page).to have_content("You have a pending claim with this bike")
      expect_axe_clean

      # The kind reads off the impound record, so match the part that doesn't vary
      click_link "view the claimed"

      expect(page).to have_current_path(registration_path(impound_claim.bike_claimed))
    end
  end
end
