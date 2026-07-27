# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Alert::Component, type: :component do
  let(:options) { {text: "some text"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(component).to be_present
    expect(component).to have_css('[role="alert"].tw:text-blue-800')
    # It doesn't have dismissable button
    expect(component).to_not have_selector("button")
  end

  describe "icon" do
    let(:icon) { ActionController::Base.helpers.inline_svg_tag("icons/envelope.svg", class: "tw:h-4 tw:w-4") }
    let(:options) { {text: "some text", icon:} }
    it "renders the passed icon instead of the default" do
      html = component.to_html
      expect(html).to include "M8.47 1.318" # the envelope path
      expect(html).to_not include "M10 .5a9.5" # the default info path
    end
  end

  describe "error" do
    let(:options) { {text: "some text", kind: "error"} }
    it "renders" do
      expect(component).to have_content "some text"
      expect(component).to have_css('[role="alert"].tw:text-red-800')
      # It doesn't have dismissable button
      expect(component).to_not have_selector("button")
    end
  end

  describe "purple" do
    let(:options) { {text: "some text", kind: "purple"} }
    it "renders" do
      expect(component).to have_content "some text"
      expect(component).to have_css('[role="alert"].tw:text-purple-800')
      expect(component.to_html).to include("tw:bg-purple-50")
      # It doesn't have dismissable button
      expect(component).to_not have_selector("button")
    end
  end

  describe "custom icon" do
    let(:options) { {text: "some text", icon: '<svg class="custom-icon"></svg>'.html_safe} }
    it "renders the given markup instead of the default icon" do
      html = component.to_html
      expect(html).to include('<svg class="custom-icon">')
      # The default info icon is not rendered
      expect(html).to_not include("M10 .5a9.5")
    end
  end

  context "success dismissable" do
    let(:options) { {text: "some text", kind: "success", dismissable: true} }
    it "renders with dismissable" do
      expect(component).to have_content "some text"
      expect(component).to have_css('[role="alert"].tw:text-green-800')
      # It has the dismissable button
      expect(component).to have_selector("button")
    end
  end
end
