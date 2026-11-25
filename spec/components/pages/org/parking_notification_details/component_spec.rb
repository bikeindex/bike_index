# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::ParkingNotificationDetails::Component, type: :component do
  let(:organization) { parking_notification.organization }
  let(:component) { render_inline(described_class.new(parking_notification:, organization:)) }

  context "a current notification" do
    let(:parking_notification) { FactoryBot.create(:parking_notification_organized, kind: "appears_abandoned_notification") }

    it "renders the two definition lists with the details" do
      expect(component).to have_css("dl", count: 2)
      expect(component).to have_css("dt", text: "Created at")
      expect(component).to have_css("dt", text: "Type")
      expect(component).to have_css("dt", text: "Notification#")
      expect(component).to have_content("This is the current parking notification")
      # blank rows still render (render_with_no_value), showing the "none" placeholder
      expect(component).to have_css("dt", text: "Message")
      expect(component).to have_css("dt", text: "Resolved")
      expect(component).to have_content("none")
    end
  end

  context "a retrieved notification" do
    let(:parking_notification) { FactoryBot.create(:parking_notification_organized, :retrieved) }

    it "shows the retrieved status and the resolved row" do
      expect(component).to have_content("has been retrieved")
      expect(component).to have_css("dt", text: "Resolved")
    end
  end

  context "skip_bike" do
    let(:parking_notification) { FactoryBot.create(:parking_notification_organized) }
    let(:component) { render_inline(described_class.new(parking_notification:, organization:, skip_bike: true)) }

    it "omits the bike row" do
      expect(component).to have_css("dt", text: "Created at")
      expect(component).not_to have_css("dt", text: "Bike")
    end
  end
end
