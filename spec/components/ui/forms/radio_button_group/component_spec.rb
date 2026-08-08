# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::RadioButtonGroup::Component, type: :component do
  let(:entries) { [{value: "", label: "All"}, {value: "active", label: "Active"}] }
  let(:button) { UI::Button::Component.build_classes(color: :secondary, size: :md) }
  let(:button_active) { UI::Button::Component::ACTIVE_COLORS[:secondary] }

  # Every purple-* color utility a class string uses, ignoring variant prefixes
  # (hover:, dark:, has-[:checked]:, is-active:, …) so the group's
  # `has-[:checked]:bg-purple-500` compares equal to the button's `bg-purple-500`.
  def purple_tokens(class_string)
    class_string.scan(%r{(?:bg|border|text|ring)-purple-\d+(?:/\d+)?}).uniq.sort
  end

  # What a class string applies under the given variant, with any deeper variant kept
  # so it still has to match: `tw:is-active:bg-purple-500` and
  # `tw:has-[:checked]:bg-purple-500` both reduce to `bg-purple-500`.
  def utilities_for(class_string, variant)
    class_string.split.filter_map { it[/\Atw:#{Regexp.escape(variant)}:(.+)\z/, 1] }.sort
  end

  let(:component) { render_inline(described_class.new(name: :status, entries:, selected: "active")) }
  let(:label) { component.css("label").first["class"] }

  it "renders radios with the selected one checked" do
    expect(component).to have_css("input[type='radio'][name='status']", count: 2, visible: :all)
    expect(component).to have_css("input[value='active'][checked]", visible: :all)
    expect(component).to have_css("label span", text: "Active")
  end

  it "uses the same purple palette as UI::Button's secondary" do
    expect(purple_tokens(label)).not_to be_empty
    expect(purple_tokens(label)).to eq(purple_tokens(button))
  end

  it "applies the button's active utilities when checked" do
    expect(utilities_for(button_active, "is-active")).not_to be_empty
    expect(utilities_for(label, "has-[:checked]")).to include(*utilities_for(button_active, "is-active"))
  end

  # Equality, not include: an extra utility here (a ring offset, say) is a visual
  # difference from the button, so it has to fail too.
  it "focuses exactly like the button, with nothing extra" do
    expect(utilities_for(button, "focus")).not_to be_empty
    expect(utilities_for(label, "has-[:focus-visible]")).to eq(utilities_for(button, "focus"))
  end

  it "sizes each chip to its label" do
    expect(component).to have_css("div.tw\\:flex-wrap")
    expect(component).to_not have_css("div.tw\\:grid")
  end

  context "full_width" do
    let(:component) do
      render_inline(described_class.new(name: "bike[frame_size]", full_width: true, selected: "m",
        entries: %w[xs s m l xl].map { |size| {value: size, label: size.upcase} }))
    end

    it "renders the chips" do
      expect(component).to have_css("input[type='radio'][name='bike[frame_size]']", count: 5, visible: :all)
      expect(component).to have_css("input[value='m'][checked]", visible: :all)
    end

    # The grid itself is UI::ButtonGroup.layout_classes, covered in its spec
    it "passes full_width through to the layout" do
      expect(component).to have_css("div.tw\\:grid")
    end
  end
end
