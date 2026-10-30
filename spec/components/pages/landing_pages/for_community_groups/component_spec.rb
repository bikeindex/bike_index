# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::ForCommunityGroups::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) do
    {recovery_displays:, total_bikes: 1_234_567, recoveries_count: 18_263, recoveries_value: 38_412_345,
     organizations_count: 1_000, sign_up_path: "/organizations/new?kind=bike_advocacy"}
  end
  let(:recovery_displays) { [] }

  it "renders the live stats" do
    expect(component).to have_text("1.2M+")
    expect(component).to have_text("18,263")
    expect(component).to have_text("$38M+")
    expect(component).to have_text("1,000+")
    expect(component).to have_css("h3", text: "A bike is STOLEN")
  end

  context "with a whole number of millions" do
    let(:options) { super().merge(total_bikes: 2_000_000) }

    it "drops the decimal" do
      expect(component).to have_text("2M+")
    end
  end
end
