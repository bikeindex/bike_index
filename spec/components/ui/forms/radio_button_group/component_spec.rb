# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::RadioButtonGroup::Component, type: :component do
  let(:entries) { [{value: "", label: "All"}, {value: "active", label: "Active"}] }

  # Every purple-* color utility a class string uses, ignoring variant prefixes
  # (hover:, dark:, has-[:checked]:, is-active:, …) so the group's
  # `has-[:checked]:bg-purple-500` compares equal to the button's `bg-purple-500`.
  def purple_tokens(class_string)
    class_string.scan(%r{(?:bg|border|text|ring)-purple-\d+(?:/\d+)?}).uniq.sort
  end

  context "default pills variant" do
    let(:component) { render_inline(described_class.new(name: :status, entries:, selected: "active")) }

    it "renders radios with the selected one checked" do
      expect(component).to have_css("input[type='radio'][name='status']", count: 2, visible: :all)
      expect(component).to have_css("input[value='active'][checked]", visible: :all)
    end

    it "uses the same purple palette as UI::Button's purple_outline" do
      button = UI::Button::Component.build_classes(color: :purple_outline, size: :md)
      label = component.css("label").first["class"]

      expect(purple_tokens(label)).not_to be_empty
      expect(purple_tokens(label)).to eq(purple_tokens(button))
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
