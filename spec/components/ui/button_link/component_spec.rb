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
    expect(html).to include("tw:bg-gray-50")
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

  context "with method" do
    let(:options) { {text: "Follow", href: "/follow", color: :primary, method: :post} }

    it "renders a button_to form submitting to the href" do
      expect(component).to have_css("form[action='/follow'][method='post']")
      expect(component).to have_css("form button[type='submit']", text: "Follow")
      expect(component.css("button").first["class"]).to include("tw:bg-blue-600")
    end

    context "with a non-post method" do
      let(:options) { {text: "Delete", href: "/thing", method: :delete} }

      it "adds the _method hidden field" do
        expect(component).to have_css("input[type='hidden'][name='_method'][value='delete']", visible: :hidden)
      end
    end

    context "with form attributes" do
      let(:options) { {text: "Revoke", href: "/thing", method: :delete, form: {onsubmit: "return confirm('Are you sure?')"}} }

      it "sets attributes on the form element" do
        expect(component).to have_css("form[onsubmit=\"return confirm('Are you sure?')\"]")
      end
    end
  end
end
