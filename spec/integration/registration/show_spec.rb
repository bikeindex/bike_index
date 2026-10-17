# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Viewing a registration", :js, type: :system do
  let(:owner) { FactoryBot.create(:user_confirmed, name: "Owner McOwnerface") }
  let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: owner) }
  let(:viewer) { FactoryBot.create(:user_confirmed, name: "Spotter Spotterson") }

  # After sending, the controller redirects to the legacy bike show, which builds
  # these gear records lazily — pre-create them so its readonly render doesn't write
  before { RearGearType.fixed && FrontGearType.fixed }

  it "sends a stolen notification to the owner through the contact form" do
    sign_in(viewer)
    expect(page).to have_content("Logged in")
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
      .and change(EmailJobs::StolenNotificationJob.jobs, :count).by(1)

    stolen_notification = StolenNotification.last
    expect(stolen_notification.bike).to eq bike
    expect(stolen_notification.sender).to eq viewer
    expect(stolen_notification.receiver).to eq owner
    expect(stolen_notification.message).to eq "I spotted this bike locked up on Main St"
    expect(stolen_notification.reference_url).to eq "https://example.com/listing"
    expect(stolen_notification.kind).to eq "stolen_permitted"
  end

  context "an organization member viewing their organization's registration" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications]) }
    let(:viewer) { FactoryBot.create(:organization_user, organization:) }
    let(:owner) { FactoryBot.create(:user_confirmed, notification_unstolen: true) }
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: owner, creation_organization: organization) }

    it "sends an organization message, switching to the stolen form and back" do
      sign_in(viewer)
      visit registration_path(bike, organization_id: organization.id)
      click_button "Message Owner"

      expect(page).to have_field("organization_message[message]")
      expect(page).to have_no_field("stolen_notification[reference_url]")

      choose "Message about theft", allow_label_click: true
      expect(page).to have_field("stolen_notification[reference_url]")
      expect(page).to have_no_field("organization_message[message]")

      choose "General message", allow_label_click: true
      fill_in "organization_message[message]", with: "Your lock is on the rack"

      Sidekiq::Job.clear_all
      expect {
        within("[data-registrations--show--message-owner-target='organizationMessage']") { click_button "Send message" }
        expect(page).to have_content("Message sent to the owner", wait: 10)
      }.to change(OrganizationMessage, :count).by(1)
      expect(OrganizationMessage.last).to have_attributes(sender_id: viewer.id, receiver_id: owner.id, message: "Your lock is on the rack")
    end
  end
end
