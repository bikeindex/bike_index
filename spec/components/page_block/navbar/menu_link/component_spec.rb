# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::MenuLink::Component, type: :component do
  let(:component) { with_request_url(url) { render_inline(described_class.new(**args)) } }
  let(:url) { "/help" }
  let(:args) { {label: "Help", path: "/help"} }

  it "resolves active from the path when active is omitted" do
    expect(component).to have_css "a.nav-link.active[href='/help']", text: "Help"
  end

  context "on another page" do
    let(:url) { "/" }

    it "renders inactive" do
      expect(component).to have_css "a.nav-link[href='/help']"
      expect(component).to_not have_css "a.active"
    end
  end

  context "with active: false" do
    let(:args) { {label: "Help", path: "/help", active: false} }

    # active: false pins the link inactive even on its own page — index.coffee sets
    # #getStolenBackLink's state, because the navbar renders from a cached fragment
    it "stays inactive on its own page" do
      expect(component).to_not have_css "a.active"
    end
  end

  context "with active: true" do
    let(:args) { {label: "Search", path: "/search/registrations", active: true} }
    let(:url) { "/" }

    it "renders active regardless of the path" do
      expect(component).to have_css "a.nav-link.active[href='/search/registrations']"
    end
  end

  context "with active: :match_controller" do
    let(:args) { {label: "Blog", path: "/news", active: :match_controller} }
    let(:url) { "/news/some-post" }

    it "matches on the controller rather than the path" do
      expect(component).to have_css "a.nav-link.active[href='/news']"
    end
  end

  context "with link_class and html_options" do
    let(:args) { {label: "Sign up", path: "/users/new", link_class: "signup-link", html_options: {id: "signUp"}} }
    let(:url) { "/" }

    it "adds them to the anchor" do
      expect(component).to have_css "a#signUp.nav-link.signup-link[href='/users/new']"
    end
  end
end
