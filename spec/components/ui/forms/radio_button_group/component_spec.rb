# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::RadioButtonGroup::Component, type: :component do
  let(:entries) { [{value: "", label: "All"}, {value: "active", label: "Active"}] }

  context "default pills variant" do
    let(:component) { render_inline(described_class.new(name: :status, entries:, selected: "active")) }

    it "renders radios with the selected one checked" do
      expect(component).to have_css("input[type='radio'][name='status']", count: 2, visible: :all)
      expect(component).to have_css("input[value='active'][checked]", visible: :all)
    end
  end

  context "chips variant" do
    let(:component) do
      render_inline(described_class.new(name: "bike[frame_size]", variant: :chips, selected: "m",
        entries: %w[xs s m l xl].map { |size| {value: size, label: size.upcase} }))
    end

    it "renders chip radios with the selected one checked" do
      expect(component).to have_css("input[type='radio'][name='bike[frame_size]']", count: 5, visible: :all)
      expect(component).to have_css("input.tw\\:peer[value='m'][checked]", visible: :all)
      expect(component).to have_css("label span", text: "M")
    end
  end
end
