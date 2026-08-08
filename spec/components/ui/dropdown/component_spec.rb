# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, type: :component do
  let(:options) { {name: "Menu"} }
  let(:component) do
    render_inline(described_class.new(**options)) { |dropdown| dropdown.with_entry_item { "Profile" } }
  end
  let(:menu) { component.css("[data-ui--dropdown-target='menu']").first }

  it "renders the menu with the shared classes" do
    expect(menu["class"]).to include("tw:min-w-44")
    expect(menu["class"]).to_not include("tw:w-max")
  end

  context "with menu_class" do
    let(:options) { {name: "Menu", menu_class: "tw:w-max"} }

    it "appends to the shared classes rather than replacing them" do
      expect(menu["class"]).to include("tw:w-max")
      expect(menu["class"]).to include("tw:min-w-44")
    end
  end
end
