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
    expect(html).to include("tw:font-extrabold")
    expect(html).to include("tw:mb-6")
    expect(component).to_not have_css("p")
  end

  context "with subtitle" do
    let(:options) { {text: "Page Title", subtitle: "The finer print"} }

    it "renders the subtitle below a tight heading" do
      expect(component.css("h1").first["class"]).to include("tw:mb-1")
      expect(component.css("p").text.strip).to eq "The finer print"
    end
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

  context "with h4 tag" do
    let(:options) { {text: "Minor section", tag: :h4} }

    it "renders an h4" do
      expect(component).to have_css("h4")
      expect(component.to_html).to include("tw:text-base")
    end
  end

  context "with custom html_class" do
    let(:options) { {text: "Custom", html_class: "tw:text-red-500"} }

    it "includes custom class" do
      expect(component.to_html).to include("tw:text-red-500")
    end
  end

  context "with block content instead of text" do
    let(:options) { {tag: :h2} }
    let(:component) { render_inline(instance) { "<em>Nested</em> markup".html_safe } }

    it "renders the block inside the heading" do
      expect(component.css("h2 em").text).to eq "Nested"
      expect(component.css("h2").text).to include "markup"
    end
  end

  context "with neither text nor content" do
    let(:options) { {} }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /required/)
    end
  end
end
