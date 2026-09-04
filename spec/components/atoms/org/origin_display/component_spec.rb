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

  context "every creation_kind" do
    let(:copy) { I18n.t(described_class.component_translation_scope.join(".")) }

    # Nothing else catches a kind with no copy: raise_on_missing_translations only fires
    # for the kind that happens to render
    it "has a label and a description, and no copy for a kind that can't happen" do
      expect(copy[:labels].keys).to match_array(Ownership.creation_kinds)
      expect(copy[:descriptions].keys).to match_array(Ownership.creation_kinds)
    end

    # The preview builds a sample ownership per kind - this catches that inverse mapping
    # setting an attribute creation_kind doesn't read back
    it "renders one ownership per kind" do
      ownerships = Atoms::Org::OriginDisplay::ComponentPreview.new.every_kind.dig(:locals, :ownerships)

      expect(ownerships.map(&:creation_kind)).to eq Ownership.creation_kinds
    end
  end

  # render? guards the rendered path, so nothing else covers a blank kind reaching these
  describe "creation_kind copy without an instance" do
    it "reads a kind's label and description, and passes blank through" do
      expect(described_class.creation_kind_humanized(:embed_partial)).to eq "old landing page"
      expect(described_class.creation_kind_description(:embed_partial))
        .to eq "registration began with incomplete registration, via organization landing page"
      expect(described_class.creation_kind_humanized(nil)).to be_nil
      expect(described_class.creation_kind_description(nil)).to be_nil
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

      it "names the POS and its broken integration" do
        expect(component).to have_content("lightspeed (broken)")
        expect(component).to have_css("[role=tooltip]", text: "automatically registered by bike shop point of sale (Lightspeed POS), whose integration is marked broken", visible: :all)
      end
    end
  end

  context "with a POS kind, a bulk_import and an origin" do
    let(:ownership) { Ownership.new(pos_kind: "ascend_pos", bulk_import_id: 1, origin: "web") }

    it "prefers the POS over the bulk import and the origin" do
      expect(component).to have_content("ascend")
    end
  end
end
