# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::Wrapper::Component, :js, type: :system do
  # These carry the alerts rather than being one, so every scenario exercises them. The
  # rest each need a preview, since reaching one otherwise means minting a token
  let(:carriers) { %w[prompt_chrome token_prompt wrapper] }

  # Text that only appears once that alert rendered, keyed by the component's directory
  # so the keys can be checked against what's on disk
  let(:alert_text) do
    # The card's heading is uppercased in CSS, so this anchors on its body - the lookbook
    # user has no stolen registration to offer
    {"claim_impound" => "You need a stolen bike registered",
     "claim_invitation" => "registered your bike on Bike Index",
     "notification_token" => "Mark bike retrieved",
     "recovery_prompt" => "Mark your bike recovered!",
     "scanned_sticker" => "You scanned",
     "sent_to_new_owner" => "You sent this"}
  end

  let(:preview_path) { "/rails/view_components/registrations/show/wrapper/component" }
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
    Rails.root.glob("app/components/registrations/show/current_alerts/*")
      .select(&:directory?).map { |dir| dir.basename.to_s }.sort - carriers
  end

  it "has a preview scenario for every kind of current alert" do
    scenarios = Registrations::Show::Wrapper::ComponentPreview.public_instance_methods(false).map(&:to_s)

    expect(alert_names).to eq alert_text.keys.sort
    alert_names.each do |alert|
      expect(scenarios).to include(alert), "CurrentAlerts::#{alert.camelize} has no preview scenario"
    end
    expect(scenarios).to include("no_overlay")
  end

  it "renders the alert each scenario is named for, and none of them without one" do
    alert_text.each do |scenario, text|
      visit "#{preview_path}/#{scenario}"

      # The preview says so rather than raising when the record it needs is absent
      expect(page).to have_no_content("Nothing to preview")
      expect(page).to have_content(text)
    end

    visit "#{preview_path}/no_overlay"

    expect(page).to have_no_content("Nothing to preview")
    alert_text.each_value { |text| expect(page).to have_no_content(text) }
  end
end
