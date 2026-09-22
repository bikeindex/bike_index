# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::MainContent::Organized::Component, type: :component do
  include Rails.application.routes.url_helpers

  let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", pos_kind: "no_pos") }
  let(:options) do
    {
      current_organization: organization,
      current_user: nil,
      passive_organization: nil,
      show_general_alert: false,
      controller_name: "dashboard",
      action_name: "index"
    }
  end
  let(:component) { render_inline(described_class.new(**options)) { "content" } }

  describe "POS integration callout" do
    it "renders the three-card callout with every link" do
      expect(component.text).to include "Register bikes automatically from your point of sale"
      expect(component).to have_link "Integrate Bike Index with Lightspeed", href: lightspeed_interface_path
      expect(component).to have_link "How the integration works", href: lightspeed_path
      expect(component).to have_link "Integrate Bike Index with Ascend", href: ascend_path
      expect(component).to have_link "Add a bike",
        href: new_organization_bike_path(organization_id: organization.to_param)
    end

    context "when the organization doesn't qualify" do
      let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", pos_kind: "lightspeed_pos") }

      it "does not render the callout" do
        expect(component.text).to_not include "Register bikes automatically from your point of sale"
      end
    end

    context "when viewing the streamlined add-a-bike page" do
      let(:options) { super().merge(controller_name: "bikes", action_name: "new") }

      it "shows a static message instead of linking to itself" do
        expect(component).to_not have_link "Add a bike"
        expect(component.text).to include "You're already viewing this page"
      end
    end

    context "when the organization's callout was dismissed" do
      let(:component) do
        vc_test_controller.request.cookies["dismissed_pos_callout_organization_ids"] = dismissed_organization_ids
        render_inline(described_class.new(**options)) { "content" }
      end

      context "with this organization's id" do
        let(:dismissed_organization_ids) { organization.id.to_s }

        it "does not render the callout" do
          expect(component.text).to_not include "Register bikes automatically from your point of sale"
        end
      end

      context "with a different organization's id" do
        let(:dismissed_organization_ids) { "0" }

        it "still renders this organization's callout" do
          expect(component.text).to include "Register bikes automatically from your point of sale"
        end
      end
    end
  end
end
