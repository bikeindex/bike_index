# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::MenuLink::Component, type: :component do
  let(:component) { render_inline(described_class.new(**args)) }
  let(:args) { {label: "Help", path: "/help"} }
  let(:link) { component.css("a").first }

  # UI::ActiveLink resolves the state in the browser, so the item renders the controller
  # rather than a class
  it "matches on the path by default" do
    expect(component).to have_css "a.nav-link[href='/help']", text: "Help"
    expect(link["data-controller"]).to eq "ui--active-link"
    expect(link["data-ui--active-link-match-value"]).to eq "path"
  end

  context "with match: :controller" do
    let(:args) { {label: "Blog", path: "/news", match: :controller} }

    it "matches on the controller rather than the path" do
      expect(link["data-ui--active-link-match-value"]).to eq "controller"
      expect(link["data-ui--active-link-routes-value"]).to eq "news"
    end
  end

  context "with an unrecognized match" do
    it "raises rather than picking a state" do
      expect { render_inline(described_class.new(label: "Help", path: "/help", match: :nonsense)) }
        .to raise_error(ArgumentError, /match/)
    end
  end

  context "with link_class and html_options" do
    let(:args) { {label: "Sign up", path: "/users/new", link_class: "signup-link", html_options: {id: "signUp"}} }

    it "adds them to the anchor" do
      expect(component).to have_css "a#signUp.nav-link.signup-link[href='/users/new']"
    end
  end
end
