# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, type: :component do
  let(:component) do
    render_inline(described_class.new(name: "Menu")) { |dropdown| dropdown.with_entry_item { "Profile" } }
  end

  # The widths are what stop a long entry wrapping or running off the screen --
  # component_system_spec measures that in a browser
  it "sizes the menu to its entries, capped against the viewport" do
    expect(component).to have_css("[data-ui--dropdown-target='menu'].tw\\:w-max.tw\\:max-w-\\[75vw\\]", visible: :all)
  end

  # The current entry fills like an active UI::Button, whose trigger sits right above it
  it "fills the current entry with the button's active color" do
    fill = UI::Button::Component::ACTIVE_COLORS[:secondary][/bg-purple-\d+/]
    expect(fill).to be_present
    expect(described_class::ACTIVE_COLORS).to include(fill)
  end
end
