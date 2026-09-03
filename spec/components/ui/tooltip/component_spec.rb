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

  context "with no trigger block" do
    let(:component) { render_inline(described_class.new(text: "tip")) }

    it "renders the default '?' button trigger" do
      trigger = component.css("[aria-describedby]").first
      expect(trigger.name).to eq "button"
      expect(trigger.text.strip).to eq "?"
    end
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

    it "keeps the custom action on the trigger and the tooltip actions on the wrapper" do
      expect(component.css("button").attr("data-action").value).to include "click->custom#handler"
      wrapper = component.css("[data-controller='ui--tooltip']").first
      expect(wrapper["data-action"]).to include "mouseenter->ui--tooltip#showOnHover"
      expect(wrapper["data-action"]).to include "focusin->ui--tooltip#showOnFocus"
    end
  end

  context "with a link in the body" do
    let(:component) do
      render_inline(described_class.new(text: "tip")) do |tooltip|
        tooltip.with_body { '<a href="/commit/abc">abc</a>'.html_safe }
        tooltip.with_tooltip_button { "?" }
      end
    end

    it "keeps the trigger a button, with the link in the popup rather than nested in the button" do
      trigger = component.css("[aria-describedby]").first
      expect(trigger.name).to eq "button"
      tooltip = component.css("[role='tooltip']").first
      expect(tooltip.at_css("a")[:href]).to eq "/commit/abc"
      expect(component.css("button a")).to be_empty
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
