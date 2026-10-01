# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::OrgTopActions::MessageOwner::Component, type: :component do
  let(:current_user) { nil }
  let(:organization) { FactoryBot.create(:organization) }
  let(:bike) { FactoryBot.create(:bike) }

  it "renders the stolen notification form, with the general message disabled" do
    render_inline(described_class.new(bike:, organization:, current_user:))

    expect(page).to have_text("Know something about this bike")
    expect(page.all("input[name='message_kind']", visible: :all).map(&:value)).to eq(%w[theft general])
    expect(page).to have_checked_field("Message about theft", visible: :all)
    expect(page).to have_field("General message", disabled: true, visible: :all)
    expect(page).to have_css("[role='tooltip']", text: "General messages can only be sent to vehicles registered with #{organization.short_name}", visible: :all)
    expect(page).to have_css("textarea[name='stolen_notification[message]'][required]", visible: :all)
    expect(page).to have_css("input[name='stolen_notification[bike_id]'][value='#{bike.id}']", visible: :all)
    expect(page).to_not have_css("textarea[name='organization_message[message]']", visible: :all)
    expect(page).not_to have_text("Or call")
  end

  context "with a stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    before { bike.current_stolen_record.update(phone: "7183914410", phone_for_users: false, phone_for_shops: false) }

    it "does not show the phone to a user without a law enforcement role" do
      render_inline(described_class.new(bike: bike.reload, organization:, current_user: FactoryBot.create(:user_confirmed)))

      expect(page).not_to have_text("Or call")
      expect(page).to have_css("[role='tooltip']", text: "General messages can only be sent to vehicles registered with #{organization.short_name}", visible: :all)
    end

    context "viewed by a law enforcement member" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: FactoryBot.create(:organization, kind: :law_enforcement)) }

      it "shows the formatted owner phone link" do
        render_inline(described_class.new(bike: bike.reload, organization:, current_user:))

        expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
      end
    end
  end

  # Whoever holds it already knows where it is, so the sighting question doesn't apply
  context "with an impounded bike" do
    let(:owner) { FactoryBot.create(:user_confirmed, notification_unstolen: true, phone: "7183914410") }
    let(:bike) { FactoryBot.create(:bike, :impounded, :with_ownership_claimed, user: owner, cycle_type: "e-scooter").reload }
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "unstolen_notifications") }
    let(:current_user) { FactoryBot.create(:organization_user, organization:) }

    it "asks what they need rather than where they saw it" do
      render_inline(described_class.new(bike:, organization:, current_user:))

      expect(page).to have_text("Know who has this e-scooter?")
      expect(page).to_not have_text("Know something about this e-scooter")
      expect(page).to have_css("textarea[placeholder^='What do you need to ask about this e-scooter']", visible: :all)
      expect(page).to have_field("General message", disabled: true, visible: :all)
      expect(page).to have_css("[role='tooltip']", text: "General messages aren't available to send to found", visible: :all)
      expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
    end
  end

  context "with an unstolen bike the owner allows contact about" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "unstolen_notifications") }
    let(:current_user) { FactoryBot.create(:organization_user, organization:) }
    let(:owner) { FactoryBot.create(:user_confirmed, notification_unstolen: true, phone: "7183914410") }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }

    it "shows the formatted owner phone link" do
      render_inline(described_class.new(bike:, organization:, current_user:))

      expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
      expect(page).to have_field("General message", disabled: true, visible: :all)
    end

    context "registered with the viewer's organization" do
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: owner, creation_organization: organization, cycle_type: "e-scooter") }

      it "defaults to an organization message, with a toggle to the stolen notification" do
        render_inline(described_class.new(bike:, organization:, current_user:))

        expect(page).to have_text("Message the owner of this e-scooter")
        expect(page).to have_checked_field("General message", visible: :all)
        expect(page).to have_field("Message about theft", disabled: false, visible: :all)
        expect(page).to_not have_css("[role='tooltip']", visible: :all)
        expect(page).to have_css("form[action='/o/#{organization.to_param}/organization_messages'] textarea[name='organization_message[message]'][placeholder='What do you want to tell the owner of this e-scooter?']", visible: :all)
        expect(page).to_not have_css("input[name='organization_message[reference_url]']", visible: :all)
        expect(page).to have_css(".tw\\:hidden[data-registrations--show--message-owner-target='stolenNotification'] input[name='stolen_notification[reference_url]']", visible: :all)
      end

      context "with the owner's notifications off" do
        it "only says so" do
          render_inline(described_class.new(bike:, organization:, current_user:, owner_notifications_off: true, active_parking_notification: true))

          expect(page).to have_css("p", text: "This User has turned off notifications for non-stolen vehicles.", visible: :all)
          expect(page).to_not have_field("message_kind", visible: :all)
          expect(page).to_not have_css("textarea", visible: :all)
          expect(page).to_not have_button("Send parking notification", visible: :all)
          expect(page).to_not have_text("Or call")
        end
      end

      context "with an active parking notification" do
        it "only links to a new parking notification" do
          render_inline(described_class.new(bike:, organization:, current_user:, active_parking_notification: true))

          expect(page).to have_text("This registration has an active Parking Notification")
          expect(page).to have_css("button[data-panel-name='parking']", text: "Send parking notification", visible: :all)
          expect(page).to_not have_field("message_kind", visible: :all)
          expect(page).to_not have_css("textarea", visible: :all)
          expect(page).to_not have_text("Or call")
        end
      end

      context "stolen" do
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, :with_stolen_record, user: owner, creation_organization: organization).reload }

        it "defaults to an organization message" do
          render_inline(described_class.new(bike:, organization:, current_user:))

          expect(bike.status).to eq "status_stolen"
          expect(page).to have_checked_field("General message", visible: :all)
          expect(page).to_not have_css("[role='tooltip']", visible: :all)
          expect(page).to have_css("textarea[name='organization_message[message]']", visible: :all)
        end
      end

      context "by phone" do
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership, :phone_registration, creation_organization: organization, owner_email: "7183914410") }

        it "shows the stolen notification form, with the general message disabled" do
          render_inline(described_class.new(bike:, organization:, current_user:))

          expect(page).to have_text("Know something about this bike")
          expect(page).to have_checked_field("Message about theft", visible: :all)
          expect(page).to have_field("General message", disabled: true, visible: :all)
          expect(page).to have_css("[role='tooltip']", text: "Registered by phone, so there's no email to send to", visible: :all)
          expect(page).to_not have_css("textarea[name='organization_message[message]']", visible: :all)
          expect(page).to_not have_css(".tw\\:hidden[data-registrations--show--message-owner-target='stolenNotification']", visible: :all)
          expect(page).to have_css("textarea[name='stolen_notification[message]']", visible: :all)
          expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
        end
      end
    end
  end
end
