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

  # Which entry is current is UI::ActiveLink's, on the link -- the li carries neither the
  # state nor the styling for it
  it "leaves the entry unflagged" do
    expect(component.css("li[role='menuitem']").first.attributes.keys).to eq(["role"])
  end

  context "with button_color: :link" do
    let(:component) do
      render_inline(described_class.new(name: "Menu", button_color: :link, active: true)) do |dropdown|
        dropdown.with_entry_item { "Profile" }
      end
    end
    let(:trigger) { component.css("button#menu").first }

    # Only the label is underlined, so the chevron beside it isn't. .twlink underlines the
    # trigger on hover and active alike, which is what the utility holds off
    it "underlines the label rather than the trigger" do
      expect(trigger["class"].split).to include("twlink", "tw:no-underline")
      expect(trigger["data-active"]).to eq "true"
      expect(component.css("button#menu span.tw\\:underline").text).to eq "Menu"
    end
  end
end
