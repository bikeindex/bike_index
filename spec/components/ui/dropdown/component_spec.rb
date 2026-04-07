# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Dropdown::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {name: "Actions", options: dropdown_options} }
  let(:dropdown_options) { ["Option 1", "Option 2"] }

  it "renders a dropdown with button and menu" do
    expect(component).to have_css("button#actions")
    expect(component).to have_css("[data-controller='dropdown']")
    expect(component).to have_css("[data-dropdown-target='menu']")
    expect(component).to have_text("Actions ▼")
    expect(component).to have_text("Option 1")
    expect(component).to have_text("Option 2")
  end

  context "with custom button content" do
    let(:options) { {name: "Menu", options: dropdown_options, button_content: "Custom"} }

    it "renders custom button content" do
      expect(component).to have_text("Custom")
    end
  end

  context "with custom id" do
    let(:options) { {name: "Menu", options: dropdown_options, id: "custom-id"} }

    it "uses custom id" do
      expect(component).to have_css("button#custom-id")
    end
  end

  context "with bottom_start direction" do
    let(:options) { {name: "Menu", options: dropdown_options, drop_direction: :bottom_start} }

    it "sets placement to bottom-start" do
      expect(component).to have_css("[data-dropdown-placement-value='bottom-start']")
    end
  end
end
