# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Alerts::Base::Component, type: :component do
  let(:options) { {text: "some text"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders, defaulting to the notice kind" do
    expect(component).to be_present
    expect(component).to have_css('[role="alert"].tw:text-blue-800')
    expect(component.to_html).to include "M10 9.25v4.5" # the default info icon
    # It doesn't have dismissable button
    expect(component).to_not have_selector("button")
  end

  describe "screen reader announcement" do
    it "announces each kind's meaning, translated" do
      %w[notice error warning success].each do |kind|
        alert = render_inline(described_class.new(text: "some text", kind:))
        expect(alert.css(".tw\\:sr-only").text).to eq I18n.t("components.ui.alerts.base.#{kind}")
      end
    end

    context "purple" do
      let(:options) { {text: "some text", kind: "purple"} }

      it "announces the meaning rather than the color" do
        expect(component.css(".tw\\:sr-only").text).to eq I18n.t("components.ui.alerts.base.info")
        expect(component.to_html).to_not include "Purple"
      end
    end
  end

  describe "icon" do
    let(:icon) { ActionController::Base.helpers.inline_svg_tag("icons/envelope.svg", class: "tw:h-4 tw:w-4") }
    let(:options) { {text: "some text", icon:} }
    it "renders the passed icon instead of the default" do
      html = component.to_html
      expect(html).to include "M8.47 1.318" # the envelope path
      expect(html).to_not include "M10 9.25v4.5" # the default info path
    end
  end

  describe "error" do
    let(:options) { {text: "some text", kind: "error"} }
    it "renders, with the exclamation triangle icon" do
      expect(component).to have_content "some text"
      expect(component).to have_css('[role="alert"].tw:text-red-800')
      expect(component.to_html).to include "M10 2.5 18.5 17.25H1.5z" # the triangle path
      expect(component.to_html).to_not include "M10 9.25v4.5" # the default info path
      # It doesn't have dismissable button
      expect(component).to_not have_selector("button")
    end
  end

  describe "header" do
    let(:options) { {text: "some text", header: "Banned user", kind: "error"} }
    it "colors the header for the kind" do
      expect(component).to have_css("h4.tw:text-red-800", text: "Banned user")
    end

    context "default_header_color" do
      let(:options) { {text: "some text", header: "Banned user", kind: "error", default_header_color: true} }
      it "renders the header in the default text color" do
        expect(component).to have_css("h4.tw\\:twtext-color", text: "Banned user")
        expect(component).to_not have_css("h4.tw:text-red-800")
      end
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
      expect(html).to_not include("M10 9.25v4.5")
    end
  end

  describe "unknown kind" do
    let(:options) { {text: "some text", kind: "bogus"} }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /unknown kind/i)
    end

    context "passed nil, rather than omitted" do
      let(:options) { {text: "some text", kind: nil} }

      it "raises" do
        expect { component }.to raise_error(ArgumentError, /unknown kind/i)
      end
    end

    context "in production" do
      before { allow(Rails).to receive(:env).and_return("production".inquiry) }

      it "renders a notice and notifies" do
        stub_const("Honeybadger", spy("Honeybadger"))

        expect(component).to have_css('[role="alert"].tw:text-blue-800')
        expect(Honeybadger).to have_received(:notify)
          .with("Unknown alert kind", hash_including(context: {kind: "bogus"}))
      end
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
