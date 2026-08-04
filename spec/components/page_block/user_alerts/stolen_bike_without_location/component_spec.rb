# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::UserAlerts::StolenBikeWithoutLocation::Component, type: :component do
  let(:bikes) { [Bike.new(id: 12, mnfg_name: "Surly", frame_model: "Cross Check", year: 2018)] }
  let(:component) { render_inline(described_class.new(bikes:)) }

  it "doesn't render without bikes" do
    expect(described_class.new(bikes: []).render?).to be_falsey
  end

  it "opens on load, linking each bike to its theft details" do
    modal = component.css("dialog#stolen-missing-location")
    expect(modal.first["data-ui--modal-open-on-connect-value"]).to eq "true"
    expect(modal.text).to include "Please add theft location"
    link = modal.css("a").first
    expect(link[:href]).to eq "/bikes/12/edit/theft_details#where-theft-happened"
    expect(link.text).to include "2018 Surly Cross Check"
  end

  # Dismissing the modal would otherwise be the end of it - the banner is how it comes back
  it "renders a banner outside the modal, linking back to it" do
    banner = component.css("[role='alert']").reject { |el| el.ancestors("dialog").any? }.first
    expect(banner.text.squish).to eq "Notice Your stolen bike is missing its theft location! Please add the theft location"
    expect(banner.css("a").first["data-open-modal"]).to eq "stolen-missing-location"
  end

  context "with a cargo bike" do
    let(:bikes) { [Bike.new(id: 12, cycle_type: :cargo)] }

    it "describes the cycle type" do
      expect(component.text).to include "where your cargo bike was stolen"
    end
  end
end
