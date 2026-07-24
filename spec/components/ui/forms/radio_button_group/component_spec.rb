# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::RadioButtonGroup::Component, type: :component do
  let(:entries) { [{value: "", label: "All"}, {value: "active", label: "Active"}] }
  let(:component) { render_inline(described_class.new(name: :search_status, entries:)) }

  # Every purple-* color utility a class string uses, ignoring variant prefixes
  # (hover:, dark:, has-[:checked]:, …) so the group's `has-[:checked]:bg-purple-500`
  # compares equal to the button's `bg-purple-500`.
  def purple_tokens(class_string)
    class_string.scan(%r{(?:bg|border|text|ring)-purple-\d+(?:/\d+)?}).uniq.sort
  end

  it "uses the same purple palette as UI::Button's purple_outline" do
    # The label carries resting (hover) and checked (active) purple in one class string,
    # while the button splits them across states, so compare against both sets combined.
    resting = UI::Button::Component.build_classes(color: :purple_outline, size: :md)
    active = UI::Button::Component.build_classes(color: :purple_outline, size: :md, active: true)
    label = component.css("label").first["class"]

    expect(purple_tokens(label)).not_to be_empty
    expect(purple_tokens(label)).to eq(purple_tokens("#{resting} #{active}"))
  end
end
