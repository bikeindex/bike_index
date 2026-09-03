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

  # Nothing else catches a kind with no copy: raise_on_missing_translations only fires
  # for the kind that happens to render
  context "every creation_kind" do
    let(:ownerships) do
      Organization.pos_kinds.select { Organization.pos?(it) }.map { Ownership.new(pos_kind: it) } +
        [Ownership.new(bulk_import_id: 1)] + Ownership.origins.map { Ownership.new(origin: it) }
    end

    it "renders a label and a tooltip for each" do
      expect(ownerships.map(&:creation_kind).uniq.count).to eq 21

      ownerships.each do |ownership|
        rendered = render_inline(described_class.new(ownership:))
        expect(rendered.css("[role=tooltip]").text).to be_present, "no tooltip for #{ownership.creation_kind}"
        expect(rendered.text.sub(rendered.css("[role=tooltip]").text, "")).to match(/[a-z]/),
          "no label for #{ownership.creation_kind}"
      end
    end
  end

  context "with a sticker origin" do
    let(:ownership) { Ownership.new(origin: "sticker") }

    it "renders the label with the description tooltip" do
      expect(component).to have_content("sticker")
      expect(component).to have_css("[role=tooltip]", text: "registration began from a sticker", visible: :all)
    end
  end

  # embed_partial and register_flow_landing_page are both landing page registrations, and
  # creation_description flattens the first to the same string as the second's label
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

      it "renders the same, the organization's integration health not being how this was registered" do
        expect(component).to have_content("lightspeed")
        expect(component).to have_css("[role=tooltip]", text: "automatically registered by bike shop point of sale (Lightspeed POS)", visible: :all)
      end
    end
  end

  # pos_kind wins over both, the way creation_kind orders them
  context "with a POS kind, a bulk_import and an origin" do
    let(:ownership) { Ownership.new(pos_kind: "ascend_pos", bulk_import_id: 1, origin: "web") }

    it "renders the POS name" do
      expect(component).to have_content("ascend")
    end
  end
end
