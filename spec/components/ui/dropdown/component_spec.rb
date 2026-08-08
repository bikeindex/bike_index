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
end
