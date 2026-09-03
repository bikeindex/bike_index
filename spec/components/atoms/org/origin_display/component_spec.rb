# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::Org::OriginDisplay::Component, type: :component do
  let(:instance) { described_class.new(creation_description:) }
  let(:component) { render_inline(instance) }

  context "blank creation_description" do
    let(:creation_description) { nil }

    it "does not render" do
      expect(component.to_html).to be_blank
    end
  end

  context "with a creation_description" do
    let(:creation_description) { Ownership.new(origin: "sticker").creation_description }

    it "renders the description with the origin_title tooltip" do
      expect(creation_description).to eq "sticker"
      expect(component).to have_content("sticker")
      expect(component).to have_css("[role=tooltip]", text: "registered via sticker", visible: :all)
    end
  end

  context "with an unregistered parking notification" do
    let(:creation_description) { Ownership.new(origin: "creator_unregistered_parking_notification").creation_description }

    it "renders the humanized label with the flow tooltip" do
      expect(creation_description).to eq "parking notification"
      expect(component).to have_content("unregistered parking notification")
      expect(component).to have_css("[role=tooltip]", text: "registered via the Unregistered Parking Notification flow", visible: :all)
    end
  end

  context "with a registration flow origin" do
    let(:creation_description) { Ownership.new(origin: "register_flow_organized").creation_description }

    it "renders the new flow label and the extended description" do
      expect(creation_description).to eq "register flow organized"
      expect(component).to have_content("new flow organized")
      expect(component).to have_css("[role=tooltip]", text: "registered by an organization member, in the multi-step registration flow", visible: :all)
    end
  end

  # embed_partial and register_flow_landing_page are both landing page registrations, and
  # only the tooltip separates them
  context "with a landing page origin" do
    let(:creation_description) { Ownership.new(origin: "embed_partial").creation_description }

    it "renders the old landing page label" do
      expect(creation_description).to eq "landing page"
      expect(component).to have_content("old landing page")
      expect(component).to have_css("[role=tooltip]", text: "registration began with incomplete registration, via organization landing page", visible: :all)
    end
  end

  context "with a registration flow landing page origin" do
    let(:creation_description) { Ownership.new(origin: "register_flow_landing_page").creation_description }

    it "renders the landing page label" do
      expect(creation_description).to eq "register flow landing page"
      expect(component).to have_content("landing page")
      expect(component).to have_css("[role=tooltip]", text: "registration began via an organization landing page, in the multi-step registration flow", visible: :all)
    end
  end

  context "with a bulk import" do
    let(:creation_description) { Ownership.new(bulk_import_id: 1).creation_description }

    it "renders the extended description" do
      expect(creation_description).to eq "bulk import"
      expect(component).to have_css("[role=tooltip]", text: "registered by spreadsheet import", visible: :all)
    end
  end
end
