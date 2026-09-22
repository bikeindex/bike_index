# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::RadioButtonGroup::Component, type: :component do
  let(:entries) { [{value: "", label: "All"}, {value: "active", label: "Active"}] }
  let(:button) { UI::Button::Component.build_classes(color: :secondary, size: :md) }
  # What a class string applies under the given variant, with any deeper variant kept
  # so it still has to match: `tw:is-active:bg-purple-500` and
  # `tw:has-[:checked]:bg-purple-500` both reduce to `bg-purple-500`.
  def utilities_for(class_string, variant)
    class_string.split.filter_map { it[/\Atw:#{Regexp.escape(variant)}:(.+)\z/, 1] }.sort
  end

  let(:component) { render_inline(described_class.new(name: :status, entries:, selected: "active")) }
  let(:label) { component.css("label").first["class"] }

  it "renders radio chips that focus like UI::Button's secondary" do
    expect(component).to have_css("input[type='radio'][name='status']", count: 2, visible: :all)
    expect(component).to have_css("input[value='active'][checked]", visible: :all)
    expect(component).to have_css("label span", text: "Active")
    # Each chip sized to its label
    expect(component).to have_css("div.tw\\:flex-wrap")
    expect(component).to_not have_css("div.tw\\:grid")

    # Equality, not include: an extra utility here (a ring offset, say) is a visual
    # difference from the button, so it has to fail too.
    expect(utilities_for(button, "focus")).not_to be_empty
    expect(utilities_for(label, "has-[:focus-visible]")).to eq(utilities_for(button, "focus"))
  end

  context "html_options" do
    let(:component) do
      render_inline(described_class.new(name: :status, entries:,
        html_options: {form: "Search_Form", class: "extra", data: {action: "change->x#y"}}))
    end

    it "applies them to each radio, keeping it sr-only" do
      expect(component).to have_css("input.tw\\:sr-only.extra[form='Search_Form'][data-action='change->x#y']", count: 2, visible: :all)
    end
  end

  context "kind: toggle" do
    let(:component) { render_inline(described_class.new(name: :status, entries:, selected: "active", kind: :toggle)) }
    let(:segment) { UI::ButtonGroup::Component::SEGMENT_CLASSES }

    it "renders radios as segments of a single track that focus like UI::ButtonGroup's" do
      expect(component).to have_css("input[value='active'][checked]", visible: :all)
      expect(component).to have_css("div.tw\\:bg-gray-100")
      expect(component).to have_no_css("div.tw\\:flex-wrap")
      expect(utilities_for(label, "has-[:focus-visible]")).to eq(utilities_for(segment, "focus"))
    end
  end

  context "full_width" do
    let(:component) do
      render_inline(described_class.new(name: "bike[frame_size]", full_width: true, selected: "m",
        entries: %w[xs s m l xl].map { |size| {value: size, label: size.upcase} }))
    end

    # The grid itself is UI::ButtonGroup.group_classes, covered in its spec
    it "renders the chips in the grid layout" do
      expect(component).to have_css("input[type='radio'][name='bike[frame_size]']", count: 5, visible: :all)
      expect(component).to have_css("input[value='m'][checked]", visible: :all)
      expect(component).to have_css("div.tw\\:grid")
    end
  end
end
