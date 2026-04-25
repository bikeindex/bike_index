# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ButtonLink::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text: "Link", href: "/test"} }

  it "renders a link styled as a button" do
    expect(component).to have_css("a[href='/test']")
    expect(component).to have_text("Link")
    html = component.to_html
    expect(html).to include("tw:inline-flex")
    expect(html).to include("tw:bg-white")
  end

  context "with primary color" do
    let(:options) { {text: "Primary", href: "/test", color: :primary} }

    it "renders primary styles" do
      expect(component.to_html).to include("tw:bg-blue-600")
    end
  end

  context "with active state" do
    let(:options) { {text: "Active", href: "/test", color: :primary, active: true} }

    it "includes active ring classes" do
      expect(component.to_html).to include("tw:ring-2")
    end
  end

  context "with extra html options" do
    let(:options) { {text: "Turbo", href: "/test", data: {turbo: false}} }

    it "passes through html options" do
      expect(component).to have_css("a[data-turbo='false']")
    end
  end
end
