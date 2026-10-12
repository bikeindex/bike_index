# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::Wrapper::Component, :js, type: :system do
  # These carry the alerts rather than being one, so every scenario exercises them. The
  # rest each need a preview, since reaching one otherwise means minting a token
  let(:carriers) { %w[prompt_chrome token_prompt wrapper] }

  # The preview to visit for each alert, and text that only appears once it rendered.
  # Keyed by the component's directory, so the keys can be checked against what's on
  # disk — an alert with states of its own previews from a class per state, so this
  # names the one that raises the card in its resting form
  let(:alert_previews) do
    # The claim card's heading is uppercased in CSS, so it anchors on its claim button
    {"claim_impound" => ["claim_impound/component/with_stolen_registration", "Claim found bike"],
     "claim_invitation" => ["component/claim_invitation", "registered your bike on Bike Index"],
     "notification_token" => ["component/notification_token", "Mark bike retrieved"],
     "recovery_prompt" => ["component/recovery_prompt", "Mark your bike recovered!"],
     "scanned_sticker" => ["component/scanned_sticker", "You scanned"],
     "sent_to_new_owner" => ["component/sent_to_new_owner", "You sent this"]}
  end

  let(:preview_path) { "/rails/view_components/pages/registrations/show/wrapper" }
  let!(:organization) { FactoryBot.create(:organization_brakebills) }
  # ShowViews only offers the owner view to the owner or a superuser — without the seeded
  # superuser, sent_to_new_owner previews the public page
  let!(:lookbook_user) { FactoryBot.create(:superuser) }

  before { stub_const("ENV", ENV.to_hash.merge("LOOKBOOK_USER_ID" => lookbook_user.id.to_s)) }
  # One registration per scenario the preview resolves for itself
  let!(:claimed_bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
  let!(:unclaimed_bike) do
    FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization,
      owner_email: "new-owner@example.com")
  end
  let!(:stolen_bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
  # Its own bike, with no ownership - so the scenarios resolving a claimed registration
  # don't land on the one carrying the claim card
  let!(:impound_record) { FactoryBot.create(:impound_record) }
  let!(:parking_notification) { FactoryBot.create(:parking_notification, organization:, bike: claimed_bike) }
  let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: claimed_bike, organization:) }

  def alert_names
    Rails.root.glob("app/components/pages/registrations/show/current_alerts/*")
      .select(&:directory?).map { |dir| dir.basename.to_s }.sort - carriers
  end

  # Every registered preview, as the path the preview controller answers to
  def preview_scenarios
    ViewComponent::Preview.all.flat_map do |preview|
      preview.public_instance_methods(false).map { |scenario| "#{preview.preview_name}/#{scenario}" }
    end
  end

  it "previews every kind of current alert, rendering the one each names and none without" do
    expect(alert_names).to eq alert_previews.keys.sort

    alert_previews.each do |alert, (path, text)|
      expect(preview_scenarios).to include("pages/registrations/show/wrapper/#{path}"),
        "CurrentAlerts::#{alert.camelize} has no preview"

      visit "#{preview_path}/#{path}"

      # The preview says so rather than raising when the record it needs is absent
      expect(page).to have_no_content("Nothing to preview")
      expect(page).to have_content(text)
    end

    expect(preview_scenarios).to include("pages/registrations/show/wrapper/component/no_overlay")

    visit "#{preview_path}/component/no_overlay"

    expect(page).to have_no_content("Nothing to preview")
    alert_previews.each_value { |(_, text)| expect(page).to have_no_content(text) }
    # Only a token prompt opens over the page, and no_overlay hasn't earned one
    expect(page).to have_no_css("dialog", visible: :all)
    expect_axe_clean

    # The claim invitation is the one alert that also raises itself as a dialog
    visit "#{preview_path}/component/claim_invitation"

    expect(page).to have_css("dialog##{Pages::Registrations::Show::CurrentAlerts::ClaimInvitation::Component::MODAL_ID}")
    expect_axe_clean
  end
end
