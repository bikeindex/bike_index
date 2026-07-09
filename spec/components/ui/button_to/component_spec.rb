# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ButtonTo::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {text: "Submit", href: "/test"} }

  it "renders a form wrapping a button styled as a button" do
    expect(component).to have_css("form[action='/test'][method='post']")
    expect(component).to have_css("button[type='submit']")
    expect(component).to have_text("Submit")
    html = component.to_html
    expect(html).to include("tw:inline-flex")
    expect(html).to include("tw:bg-gray-50")
  end

  context "with error color" do
    let(:options) { {text: "Delete", href: "/test", color: :error} }

    it "renders error styles" do
      expect(component.to_html).to include("tw:bg-red-600")
    end
  end

  context "with method" do
    let(:options) { {text: "Update", href: "/test", method: :put} }

    it "submits via the method, not post" do
      expect(component).to have_css("input[name='_method'][value='put']", visible: :all)
    end
  end

  context "with invalid color" do
    let(:options) { {text: "Fallback", href: "/test", color: :invalid} }

    it "falls back to secondary" do
      expect(component.to_html).to include("tw:bg-gray-50")
    end
  end

  context "with active state" do
    let(:options) { {text: "Active", href: "/test", color: :primary, active: true} }

    it "includes active ring classes" do
      expect(component.to_html).to include("tw:ring-2")
    end
  end
end
