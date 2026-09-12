# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::ContactImpound::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, owner: false) }
  # An e-scooter, so every string has to name the registration's cycle type
  let(:bike) { FactoryBot.create(:bike, :impounded, :with_ownership_claimed, user: finder, cycle_type: "e-scooter").reload }
  let(:finder) { FactoryBot.create(:user_confirmed, phone: "2223334444") }
  let(:organization_role) { FactoryBot.create(:organization_role_claimed) }
  let(:current_user) { organization_role.user.reload }
  before { organization_role.organization.update_attribute :is_paid, true }

  it "offers the message form, with the phone" do
    expect(bike.status_found?).to be_truthy
    render_inline(component)
    expect(page).to have_text("Know who has this e-scooter?")
    expect(page).to have_button("Contact the finder")
    expect(page).to have_css("form[action='/stolen_notifications'] textarea[name='stolen_notification[message]']", visible: :all)
    expect(page).to have_css("input[name='stolen_notification[bike_id]'][value='#{bike.id}']", visible: :all)
    expect(page).to have_button("Send message")
    expect(page).to have_link("222-333-4444", href: "tel:222-333-4444")
  end

  context "impounded by an organization" do
    let(:bike) { FactoryBot.create(:impound_record, :with_organization, bike: e_scooter).bike.reload }
    let(:e_scooter) { FactoryBot.create(:bike, :with_ownership_claimed, user: finder, cycle_type: "e-scooter") }

    it "labels the button for an impound rather than a find" do
      expect(bike.status_found?).to be_falsey
      render_inline(component)
      expect(page).to have_button("Contact the owner")
    end
  end

  context "viewer's organization qualifies on nothing" do
    before { organization_role.organization.update_attribute :is_paid, false }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "not impounded" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: finder) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "viewer is the owner" do
    let(:component) { described_class.new(bike:, current_user:, owner: true) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  # The allowance is about which organizations may ask, not about overriding the answer
  context "owner declined unstolen notifications" do
    before { finder.update(notification_unstolen: false) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
