# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Tooltip::Component, type: :component do
  let(:component) do
    render_inline(described_class.new(text: "5–9 mi")) { "trigger".html_safe }
  end

  it "renders the tooltip text and trigger" do
    expect(component.css("[role='tooltip']").text.strip).to eq "5–9 mi"
    expect(component.text).to include "trigger"
  end

  it "wires aria-describedby to the tooltip id" do
    tooltip_id = component.css("[role='tooltip']").attr("id").value
    expect(tooltip_id).to be_present
    expect(component.css("[aria-describedby='#{tooltip_id}']")).to be_present
  end

  it "renders the trigger as a button" do
    expect(component.css("[aria-describedby]").first.name).to eq "button"
  end

  context "with a body slot" do
    let(:component) do
      render_inline(described_class.new) do |tooltip|
        tooltip.with_body { '<span class="unit-imperial">5 mi</span>'.html_safe }
        "trigger".html_safe
      end
    end

    it "renders the slot content in the tooltip body" do
      tooltip = component.css("[role='tooltip']")
      expect(tooltip.css(".unit-imperial").text).to eq "5 mi"
    end
  end

  context "with a tooltip_button slot that sets a custom action" do
    let(:component) do
      render_inline(described_class.new(text: "tip")) do |tooltip|
        tooltip.with_tooltip_button(data: {action: "click->custom#handler"})
      end
    end

    it "chains the custom action with the tooltip actions" do
      action = component.css("button").attr("data-action").value
      expect(action).to include "click->custom#handler"
      expect(action).to include "mouseenter->ui--tooltip#showOnHover"
      expect(action).to include "focusin->ui--tooltip#showOnFocus"
    end
  end

  context "with multiple instances" do
    let(:components) do
      [
        render_inline(described_class.new(text: "one")) { "a".html_safe },
        render_inline(described_class.new(text: "two")) { "b".html_safe }
      ]
    end

    it "generates unique tooltip ids" do
      ids = components.map { |c| c.css("[role='tooltip']").attr("id").value }
      expect(ids.uniq.size).to eq 2
    end
  end
end
