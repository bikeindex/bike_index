# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::ForCommunityGroups::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) do
    {recovery_displays:, total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345,
     organizations_count: 1_000, sign_up_path: "/organizations/new?kind=bike_advocacy"}
  end
  let(:recovery_displays) { [] }

  it "renders the sections and live stats" do
    expect(component).to have_css("h1", text: "Help your riders get their bikes back.")
    expect(component).to have_link("Sign up for free", href: "/organizations/new?kind=bike_advocacy", count: 2)
    expect(component).to have_link("New for e-bike riders", href: "#ebikes")
    expect(component).to have_css("section#ebikes")
    expect(component).to have_link("Check e-bike rules in your state", href: "/ebike-rules")
    expect(component).to have_css("h2", text: "A registered bike is a bike that can come home.")
    expect(component).to have_css("h3", text: "A bike is STOLEN")
    expect(component).to have_text("1.2M+")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38M+")
    expect(component).to have_text("1,000+")
    expect(component).to have_link("@GOBuffalo", href: "https://twitter.com/GOBuffalo")
    expect(component).to have_link("Bike Index for bike shops", href: "/for_bike_shops")
    expect(component).to have_link("Embed a registration form",
      href: "/info/embed-a-bike-index-registration-form-on-your-website")
  end

  context "with a whole number of millions" do
    let(:options) { super().merge(total_bikes: 2_000_000) }

    it "drops the decimal" do
      expect(component).to have_text("2M+")
    end
  end

  context "with recovery displays" do
    let(:recovery_displays) { [FactoryBot.create(:recovery_display_with_photo, quote: "Police found the bike")] }

    it "renders them" do
      expect(component).to have_css("blockquote", text: "Police found the bike")
    end
  end
end
