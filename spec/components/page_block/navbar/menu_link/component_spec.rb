# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Navbar::MenuLink::Component, type: :component do
  let(:component) { render_inline(described_class.new(**args)) }
  let(:args) { {label: "Help", path: "/help"} }

  # The navbar's cache is shared by every page, so :auto and :match_controller can only
  # describe what makes the link active — page-block--navbar decides it
  it "hands the path rule to the navbar controller when active is omitted" do
    expect(component).to have_css "a.nav-link[href='/help'][data-active-path='true']", text: "Help"
    expect(component).to_not have_css "a.active"
    expect(component).to_not have_css "a[data-active-routes]"
  end

  context "with active: :match_controller" do
    let(:args) { {label: "Blog", path: "/news", active: :match_controller} }

    it "hands over the path's controller instead" do
      expect(component).to have_css "a.nav-link[href='/news'][data-active-routes='news']"
      expect(component).to_not have_css "a[data-active-path]"
    end

    context "with a path this app does not route" do
      let(:args) { {label: "Discuss", path: "https://discuss.bikeindex.org", active: :match_controller} }

      it "leaves the link with no rule, so it never activates" do
        expect(component).to have_css "a.nav-link"
        expect(component).to_not have_css "a[data-active-routes], a[data-active-path]"
      end
    end
  end

  context "with active: true" do
    let(:args) { {label: "Search", path: "/search/registrations", active: true} }

    it "renders active without a rule" do
      expect(component).to have_css "a.nav-link.active[href='/search/registrations']"
      expect(component).to_not have_css "a[data-active-path]"
    end
  end

  context "with active: false" do
    let(:args) { {label: "Logout", path: "/logout", active: false} }

    it "pins the link inactive" do
      expect(component.css("a").first["class"]).to eq "nav-link"
      expect(component).to_not have_css "a[data-active-path]"
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
    let(:args) do
      {label: "Sign up", path: "/users/new", link_class: "signup-link",
       html_options: {id: "signUp", data: {email: "party@bikeindex.org"}}}
    end

    it "adds them to the anchor, keeping its own data" do
      expect(component).to have_css "a#signUp.nav-link.signup-link[href='/users/new']"
      expect(component).to have_css "a[data-email='party@bikeindex.org'][data-active-path='true']"
    end
  end
end
