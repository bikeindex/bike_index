# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::Org::OriginDisplay::Component, type: :component do
  let(:instance) { described_class.new(ownership:) }
  let(:component) { render_inline(instance) }

  context "blank ownership" do
    let(:ownership) { nil }

    it "does not render" do
      expect(component.to_html).to be_blank
    end
  end

  context "with a sticker origin" do
    let(:ownership) { Ownership.new(origin: "sticker") }

    it "renders the label with the description tooltip" do
      expect(component).to have_content("sticker")
      expect(component).to have_css("[role=tooltip]", text: "registration began from a sticker", visible: :all)
    end
  end

  # embed_partial and register_flow_landing_page are both landing page registrations, so
  # only the tooltip separates "old landing page" from "landing page"
  context "with a landing page origin" do
    let(:ownership) { Ownership.new(origin: "embed_partial") }

    it "renders the old landing page label" do
      expect(component).to have_content("old landing page")
      expect(component).to have_css("[role=tooltip]", text: "registration began with incomplete registration, via organization landing page", visible: :all)
    end

    context "register_flow_landing_page" do
      let(:ownership) { Ownership.new(origin: "register_flow_landing_page") }

      it "renders the landing page label" do
        expect(component).to have_content("landing page")
        expect(component).to have_css("[role=tooltip]", text: "registration began via an organization landing page, in the multi-step registration flow", visible: :all)
      end
    end
  end

  context "with a POS kind" do
    let(:ownership) { Ownership.new(pos_kind: "lightspeed_pos") }

    it "renders the POS name" do
      expect(component).to have_content("lightspeed")
      expect(component).to have_css("[role=tooltip]", text: "automatically registered by bike shop point of sale (Lightspeed POS)", visible: :all)
    end

    context "broken_lightspeed_pos" do
      let(:ownership) { Ownership.new(pos_kind: "broken_lightspeed_pos") }

      it "names the POS and its broken integration" do
        expect(component).to have_content("lightspeed (broken)")
        expect(component).to have_css("[role=tooltip]", text: "automatically registered by bike shop point of sale (Lightspeed POS), whose integration is marked broken", visible: :all)
      end
    end
  end
end
