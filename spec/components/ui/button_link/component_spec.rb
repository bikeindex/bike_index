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

  it "always applies the active classes (inert until data-active/pressed)" do
    tokens = component.css("a").first["class"].split
    expect(tokens).to include("tw:is-active:ring-2", "tw:is-active:bg-purple-500")
    expect(component).to have_no_css("a[data-active]")
  end

  context "active: true" do
    let(:options) { {text: "Active", href: "/test", active: true, data: {turbo: false}} }

    it "flags the link data-active, keeping the passed data attributes" do
      expect(component).to have_css("a[data-active='true'][data-turbo='false']")
    end
  end

  context "disabled: true" do
    let(:options) { {text: "Disabled", href: "/test", disabled: true, aria: {controls: "panel"}} }

    # An <a> takes no disabled attribute, so dropping the href is what makes it
    # unfollowable — aria-disabled is what says so, and what the styling hangs off
    it "renders a link that can't be followed, keeping the passed aria" do
      expect(component).to have_css("a[aria-disabled='true'][role='link'][tabindex='-1']", text: "Disabled")
      expect(component).to have_no_css("a[href]")
      expect(component).to have_css("a[aria-controls='panel']")
      expect(component.css("a").first["class"].split).to include("tw:aria-disabled:opacity-50", "tw:aria-disabled:cursor-not-allowed")
    end

    it "keeps hover off it" do
      hovers = component.css("a").first["class"].split.grep(/hover:/)
      expect(hovers).to be_present
      expect(hovers.grep_v(/not-aria-disabled:/)).to eq([])
    end

    context "with method" do
      let(:options) { {text: "Follow", href: "/follow", method: :post, disabled: true} }

      it "disables the button the form submits with" do
        expect(component).to have_css("form button[type='submit'][disabled]", text: "Follow")
      end
    end
  end

  context "with aria-controls" do
    let(:options) { {text: "Toggle", href: "/test", aria: {controls: "panel"}} }

    it "renders aria-controls" do
      expect(component.to_html).to include('aria-controls="panel"')
    end
  end

  context "with extra html options" do
    let(:options) { {text: "Turbo", href: "/test", data: {turbo: false}} }

    it "passes through html options" do
      expect(component).to have_css("a[data-turbo='false']")
    end
  end

  context "with html_class" do
    let(:options) { {text: "Wide", href: "/test", html_class: "tw:w-full"} }

    it "builds it into the link's classes" do
      expect(component.css("a").first["class"].split).to include("tw:w-full", "tw:inline-flex")
    end
  end

  context "with class in html_options" do
    let(:options) { {text: "Wide", href: "/test", class: "tw:w-full"} }

    it "raises, naming html_class" do
      expect { instance }.to raise_error(ArgumentError, /you must use the keyword arg html_class/)
    end
  end

  context "with an unknown color" do
    let(:options) { {text: "Link", href: "/test", color: :invalid} }

    it "raises, naming the colors it takes" do
      expect { instance }.to raise_error(ArgumentError, /unknown color :invalid, expected one of: primary, secondary/)
    end
  end

  context "with a size for link color" do
    let(:options) { {text: "Link", href: "/test", color: :link, size: :lg} }

    it "raises" do
      expect { instance }.to raise_error(ArgumentError, /size is not supported/)
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

    context "with params" do
      let(:options) { {text: "Assign", href: "/thing", method: :post, params: {membership_id: 42}} }

      it "renders params as hidden fields" do
        expect(component).to have_css("input[type='hidden'][name='membership_id'][value='42']", visible: :hidden)
      end
    end
  end
end
