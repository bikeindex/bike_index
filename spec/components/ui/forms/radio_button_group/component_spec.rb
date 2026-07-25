# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::RadioButtonGroup::Component, type: :component do
  let(:entries) { [{value: "", label: "All"}, {value: "active", label: "Active"}] }
  let(:component) { render_inline(described_class.new(name: :search_status, entries:)) }
  let(:label) { component.css("label").first["class"] }
  let(:button) { UI::Button::Component.build_classes(color: :purple_outline, size: :md) }

  # Every purple-* color utility a class string uses, ignoring variant prefixes
  # (hover:, dark:, has-[:checked]:, is-active:, …) so the group's
  # `has-[:checked]:bg-purple-500` compares equal to the button's `bg-purple-500`.
  def purple_tokens(class_string)
    class_string.scan(%r{(?:bg|border|text|ring)-purple-\d+(?:/\d+)?}).uniq.sort
  end

  # The utilities a class string applies under a single variant, e.g. "is-active" or
  # "has-[:checked]" — `tw:is-active:bg-purple-500` and
  # `tw:has-[:checked]:bg-purple-500` both reduce to `bg-purple-500`.
  def utilities_for(class_string, variant)
    class_string.split.filter_map { it[/\Atw:#{Regexp.escape(variant)}:([^:]+)\z/, 1] }.sort
  end

  it "uses the same purple palette as UI::Button's purple_outline" do
    expect(purple_tokens(label)).not_to be_empty
    expect(purple_tokens(label)).to eq(purple_tokens(button))
  end

  it "applies the button's active utilities when checked" do
    expect(utilities_for(button, "is-active")).not_to be_empty
    expect(utilities_for(label, "has-[:checked]")).to include(*utilities_for(button, "is-active"))
  end
end
