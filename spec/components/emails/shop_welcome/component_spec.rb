# frozen_string_literal: true

require "rails_helper"

RSpec.describe Emails::ShopWelcome::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", name: "Shifty Bike Shop") }
  let(:component) { render_inline(described_class.new(organization:)) }
  let(:dashboard_url) { "#{ENV["BASE_URL"]}/o/#{organization.to_param}" }

  before { Counts.assign_for("total_bikes", 1_834_000) && Counts.assign_for("recoveries", 18_625) && Counts.assign_for("organizations", 1_873) }

  it "leads with connecting the POS, and links to the dashboard" do
    expect(organization.pos_kind).to eq "no_pos"
    expect(component).to have_content("Shifty Bike Shop is set up on Bike Index")
    expect(component).to have_content("One step left: connect your POS")
    expect(component).to have_content("Connect your POS so no bike gets missed.")
    expect(component).to have_content("Shifty Bike Shop on Bike Index")
    expect(component.css("a").map { it[:href] }.compact_blank)
      .to eq([dashboard_url, dashboard_url, "#{ENV["BASE_URL"]}/bikebook", "#{ENV["BASE_URL"]}/ebike-rules",
        "#{ENV["BASE_URL"]}/privacy", "#{ENV["BASE_URL"]}/my_account/edit"])
    expect(component.css("a.binx-button").map { it.text.strip }).to eq(["Connect your POS now"])
  end

  it "renders the registry's live counts" do
    expect(component.css("td p").map { it.text.strip }.each_cons(2).select { |number, _| number.match?(/\A[\d,.]+M?\+?\z/) })
      .to eq([["1.8M+", "bikes registered"], ["18,625", "stolen bikes recovered"], ["1,800+", "partner shops, police, and cities"]])
  end

  context "with a POS connected" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_shop", name: "Shifty Bike Shop", pos_kind: "lightspeed_pos") }

    it "leaves out the POS step" do
      expect(component).to have_content("Shifty Bike Shop is set up on Bike Index")
      expect(component).to_not have_content("connect your POS")
      expect(component).to_not have_content("Connect your POS")
      expect(component.css("a").map { it[:href] }.compact_blank.count(dashboard_url)).to eq 1
      expect(component.css("a.binx-button").map { it.text.strip }).to eq(["Open your dashboard"])
    end
  end
end
