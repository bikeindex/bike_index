# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::MyAccount::Show::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed, name: "Alexandra") }
  let(:locks_tab) { false }
  let(:pagy) { Pagy::Offset.new(count: user.bikes.count, page: 1, limit: 10) }
  let(:page_params) { {} }
  let(:component) do
    render_inline(described_class.new(user: user.reload, bikes: user.bikes.reorder(:id), pagy:, locks: user.locks, locks_tab:, page_params:))
  end

  context "without bikes or locks" do
    it "renders the header, the empty state and the prompts" do
      expect(component).to have_css("h1", text: "Alexandra on Bike Index")
      expect(component).not_to have_text("0 bikes")
      expect(component).to have_text("No bikes registered yet")
      expect(component).to have_link("+ Register a bike", href: "/register")
      expect(component).to have_link("Update profile")
      expect(component).to have_link("Donate", href: %r{/donate\z})
      expect(component).to have_text("Strava")
    end

    context "on the locks tab" do
      let(:locks_tab) { true }

      it "renders the locks empty state" do
        expect(component).to have_text("No locks registered yet")
        expect(component).to have_link("Add a lock")
      end
    end
  end

  context "with bikes and a lock" do
    let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:, serial_number: "LISTED-123") }
    let!(:lock) { FactoryBot.create(:lock, user:, key_serial: "KEY-9") }

    it "renders the tabs and the bikes" do
      expect(component).to have_link("Bikes")
      expect(component).to have_link("Locks", href: "/my_account?active_tab=locks")
      expect(component).to have_text("LISTED-123")
    end

    context "with an unassigned_bike_org alert" do
      let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
      let!(:user_alert) { FactoryBot.create(:user_alert, user:, bike:, organization:, kind: "unassigned_bike_org") }

      before { UserAlert.refresh_alert_slugs(user) }

      it "renders it with its bike, saying 'this one'" do
        expect(component).to have_css("li [role=alert]", text: "but this one is not")
        expect(component).not_to have_css("[role=alert] a[href='/bikes/#{bike.id}']")
      end
    end

    context "on the locks tab" do
      let(:locks_tab) { true }

      it "lists the locks" do
        expect(component).to have_text("KEY-9")
        expect(component).to have_link("Edit", href: "/locks/#{lock.id}/edit")
      end
    end
  end
end
