# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::ForCommunityGroups::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) do
    {recovery_displays:, total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345,
     organizations_count: 1_000}
  end
  let(:recovery_displays) { [] }

  it "renders the sections and live stats" do
    expect(component).to have_css("h1", text: "Help your riders get their bikes back.")
    expect(component).to have_link("Sign up for free", href: "/organizations/new", count: 2)
    expect(component).to have_link("New for e-bike riders", href: "#ebikes")
    expect(component).to have_css("section#ebikes")
    expect(component).to have_link("Check e-bike rules in your state", href: "/ebike-rules")
    expect(component).to have_css("h2", text: "A registered bike is a bike that can come home.")
    expect(component).to have_css("h3", text: "A bike is STOLEN")
    expect(component).to have_text("1M+")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38M+")
    expect(component).to have_text("1,000+")
    expect(component).to have_link("@GOBuffalo", href: "https://twitter.com/GOBuffalo")
    expect(component).to have_link("Bike Index for bike shops", href: "/for_bike_shops")
    expect(component).to_not have_text("Recovered, in their own words")
  end

  context "with recovery displays" do
    let(:recovery_displays) do
      FactoryBot.create_list(:recovery_display_with_photo, 4, quote: "Police found the bike", quote_by: "Sandy")
    end

    it "renders the first three" do
      expect(component).to have_text("Recovered, in their own words")
      expect(component).to have_link("See all recovery stories", href: "/recovery_stories")
      expect(component).to have_css("blockquote", text: "Police found the bike", count: 3)
      expect(component).to have_css("strong", text: "Sandy", count: 3)
    end
  end
end
