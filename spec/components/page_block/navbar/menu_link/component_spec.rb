# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::MenuLink::Component, type: :component do
  let(:component) { render_inline(described_class.new(**args)) }
  let(:args) { {label: "Help", path: "/help"} }
  let(:link) { component.css("a").first }

  # UI::ActiveLink resolves the state in the browser, so an item that passes no :active
  # renders the controller rather than a class
  it "leaves the current-page check to the path when active is omitted" do
    expect(component).to have_css "a.nav-link[href='/help']", text: "Help"
    expect(link["data-controller"]).to eq "ui--active-link"
    expect(link["data-ui--active-link-match-value"]).to eq "path"
  end

  context "with active: false" do
    let(:args) { {label: "Help", path: "/help", active: false} }

    it "pins the link inactive, without the browser resolving it" do
      expect(component).to_not have_css "a.active"
      expect(link.attributes).to_not have_key("data-controller")
    end
  end

  context "with active: true" do
    let(:args) { {label: "Search", path: "/search/registrations", active: true} }

    it "renders active regardless of the path" do
      expect(component).to have_css "a.nav-link.active[href='/search/registrations']"
      expect(link.attributes).to_not have_key("data-controller")
    end
  end

  context "with active: :match_controller" do
    let(:args) { {label: "Blog", path: "/news", active: :match_controller} }

    it "matches on the controller rather than the path" do
      expect(link["data-ui--active-link-match-value"]).to eq "controller"
      expect(link["data-ui--active-link-route-value"]).to eq "news#index"
    end
  end

  # The manifests' vocabulary is an alias layer over UI::ActiveLink's own match names, which
  # a caller can pass straight through
  context "with active: :controller, UI::ActiveLink's name for it" do
    let(:args) { {label: "Blog", path: "/news", active: :controller} }

    it "matches the same as :match_controller" do
      expect(link["data-ui--active-link-match-value"]).to eq "controller"
    end
  end

  context "with an unrecognized active" do
    # nil used to mean :auto, so a caller reaching for a falsey value has to say which
    it "raises rather than picking a state" do
      expect { described_class.new(label: "Help", path: "/help", active: nil) }
        .to raise_error(ArgumentError, /Invalid active/)
    end
  end

  context "with link_class and html_options" do
    let(:args) { {label: "Sign up", path: "/users/new", link_class: "signup-link", html_options: {id: "signUp"}} }

    it "adds them to the anchor" do
      expect(component).to have_css "a#signUp.nav-link.signup-link[href='/users/new']"
    end
  end
end
