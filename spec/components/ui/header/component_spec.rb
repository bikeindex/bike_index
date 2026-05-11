# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Header::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text: "Page Title"} }

  it "renders an h1 by default" do
    expect(component).to have_css("h1")
    expect(component).to have_text("Page Title")
    html = component.to_html
    expect(html).to include("tw:text-2xl")
    expect(html).to include("tw:font-bold")
  end

  context "with h2 tag" do
    let(:options) { {text: "Section", tag: :h2} }

    it "renders an h2" do
      expect(component).to have_css("h2")
      expect(component.to_html).to include("tw:text-xl")
    end
  end

  context "with h3 tag" do
    let(:options) { {text: "Subsection", tag: :h3} }

    it "renders an h3" do
      expect(component).to have_css("h3")
      expect(component.to_html).to include("tw:text-lg")
    end
  end

  context "with custom html_class" do
    let(:options) { {text: "Custom", html_class: "tw:text-red-500"} }

    it "includes custom class" do
      expect(component.to_html).to include("tw:text-red-500")
    end
  end
end
