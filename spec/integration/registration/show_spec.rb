# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Viewing a registration", :js, type: :system do
  let(:owner) { FactoryBot.create(:user_confirmed, name: "Owner McOwnerface") }
  let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: owner) }
  let(:viewer) { FactoryBot.create(:user_confirmed, name: "Spotter Spotterson") }

  # After sending, the controller redirects to the legacy bike show, which builds
  # these gear records lazily — pre-create them so its readonly render doesn't write
  before { RearGearType.fixed && FrontGearType.fixed }

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_content("Logged in", wait: 5)
  end

  it "sends a stolen notification to the owner through the contact form" do
    sign_in(viewer)
    visit registration_path(bike)

    # The message form is collapsed until the viewer opens it
    expect(page).to have_no_field("stolen_notification[message]")

    click_button "Contact the owner"

    fill_in "stolen_notification[message]", with: "I spotted this bike locked up on Main St"
    fill_in "stolen_notification[reference_url]", with: "https://example.com/listing"

    Sidekiq::Job.clear_all
    expect {
      click_button "Send message"
      expect(page).to have_content("Thanks for looking out!", wait: 10)
    }.to change(StolenNotification, :count).by(1)
      .and change(Email::StolenNotificationJob.jobs, :count).by(1)

    stolen_notification = StolenNotification.last
    expect(stolen_notification.bike).to eq bike
    expect(stolen_notification.sender).to eq viewer
    expect(stolen_notification.receiver).to eq owner
    expect(stolen_notification.message).to eq "I spotted this bike locked up on Main St"
    expect(stolen_notification.reference_url).to eq "https://example.com/listing"
    expect(stolen_notification.kind).to eq "stolen_permitted"
  end
end
