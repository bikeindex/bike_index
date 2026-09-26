# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::MyAccount::Show::BikeBox::Component, type: :component do
  let(:instance) { described_class.new(bike:, current_user: user, user_alerts: described_class.user_alerts(user.reload)) }
  let(:component) { render_inline(instance) }
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:bike) do
    FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer: FactoryBot.create(:manufacturer, name: "Surly"),
      frame_model: "Midnight Special", serial_number: "SUR-77120934")
  end

  it "renders the registration, with no alerts" do
    expect(component).to have_link(href: "/bikes/#{bike.id}")
    expect(component).to have_css("strong", text: "Surly")
    expect(component).to have_text("SUR-77120934")
    expect(component).to have_link("List for sale")
    expect(component).to have_link("Mark bike stolen")
    expect(component).not_to have_css("[role=alert]")
  end

  context "with an unassigned_bike_org alert" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let!(:user_alert) { FactoryBot.create(:user_alert, user:, bike:, organization:, kind: "unassigned_bike_org") }
    let!(:other_alert) { FactoryBot.create(:user_alert, user:, organization:, kind: "unassigned_bike_org", bike: FactoryBot.create(:bike)) }

    before { UserAlert.refresh_alert_slugs(user) }

    it "renders only this bike's alert" do
      expect(component).to have_css("[role=alert]", count: 1)
      expect(component).to have_text("associated with Brakebills")
      expect(component).to have_link("Add it now!", href: "/user_alerts/#{user_alert.id}?add_bike_organization=true")
      expect(component).to have_link("Ignore this suggestion", href: "/user_alerts/#{user_alert.id}?alert_action=dismiss")
    end
  end

  context "with the registration unfinished" do
    before do
      FactoryBot.create(:b_param_unfinished_registration, creator: user, created_bike_id: bike.id,
        params: {acknowledgment_pending: true, bike: {manufacturer_id: bike.manufacturer_id, owner_email: user.email}})
    end

    it "renders the unfinished registration alert, above the registration" do
      expect(component).to have_css("li > div:first-child [role=alert]", text: "Your Surly bike isn't registered yet!")
      expect(component).to have_link("finish the required steps")
    end
  end

  context "with caching", :caching do
    include_context :caching_basic

    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }

    def render_box
      with_controller_class(ApplicationController) do
        render_inline(described_class.new(bike: bike.reload, current_user: user,
          user_alerts: described_class.user_alerts(user.reload)))
      end
    end

    it "caches the registration, and renders alerts outside the cache" do
      keys = fragments_written { render_box }
      expect(keys.count).to eq 1
      expect(keys.first).to include(bike.cache_key_with_version)
      expect(fragments_written { render_box }).to eq([])

      FactoryBot.create(:user_alert, user:, bike:, organization:, kind: "unassigned_bike_org")
      UserAlert.refresh_alert_slugs(user)
      rendered = nil
      expect(fragments_written { rendered = render_box }).to eq([])
      expect(rendered).to have_text("associated with Brakebills")
    end
  end
end
