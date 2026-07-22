# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::OriginDisplay::Component, type: :component do
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
      expect(component).to have_css("[role=tooltip]", text: "Registered via sticker", visible: :all)
    end
  end
end
