# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::SectionLabel::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {text: "Bike info"} }

  it "renders the label without a divider" do
    expect(component).to have_text "Bike info"
    expect(component.css("div").count).to eq 1
  end

  context "with divider" do
    let(:options) { {text: "Your info", divider: true} }

    it "renders a divider above the label" do
      expect(component).to have_text "Your info"
      expect(component.css("div").count).to eq 2
    end
  end
end
