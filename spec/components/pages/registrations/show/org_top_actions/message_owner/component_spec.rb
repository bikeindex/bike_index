# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::OrgTopActions::MessageOwner::Component, type: :component do
  let(:current_user) { nil }
  let(:organization) { FactoryBot.create(:organization) }
  let(:bike) { FactoryBot.create(:bike) }

  it "renders the message form" do
    render_inline(described_class.new(bike:, organization:, current_user:))

    expect(page).to have_text("Know something about this bike")
    expect(page).to have_css("textarea[name='stolen_notification[message]'][required]", visible: :all)
    expect(page).to have_css("input[name='stolen_notification[bike_id]'][value='#{bike.id}']", visible: :all)
    expect(page).not_to have_text("Or call")
  end

  context "with a stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    before { bike.current_stolen_record.update(phone: "7183914410", phone_for_users: false, phone_for_shops: false) }

    it "does not show the phone to a user without a law enforcement role" do
      render_inline(described_class.new(bike: bike.reload, organization:, current_user: FactoryBot.create(:user_confirmed)))

      expect(page).not_to have_text("Or call")
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
    end

    context "registered with the viewer's organization" do
      let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: owner, creation_organization: organization, cycle_type: "e-scooter") }

      it "asks for a message to the owner, not a sighting" do
        render_inline(described_class.new(bike:, organization:, current_user:))

        expect(page).to have_text("Message the owner of this e-scooter")
        expect(page).to_not have_text("Know something about this e-scooter")
        expect(page).to have_css("form[action='/o/#{organization.to_param}/organization_messages']", visible: :all)
        expect(page).to have_css("textarea[name='organization_message[message]'][placeholder='What do you want to tell the owner of this e-scooter?']", visible: :all)
        expect(page).to_not have_css("input[name$='[reference_url]']", visible: :all)
      end

      context "by phone" do
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership, :phone_registration, creation_organization: organization, owner_email: "7183914410") }

        it "only shows the phone" do
          render_inline(described_class.new(bike:, organization:, current_user:))

          expect(page).to have_text("Message the owner of this bike")
          expect(page).to_not have_css("textarea", visible: :all)
          expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
        end
      end
    end
  end
end
