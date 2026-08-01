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

  context "with a cargo bike" do
    let(:bikes) { [Bike.new(id: 12, cycle_type: :cargo)] }

    it "describes the cycle type" do
      expect(component.text).to include "where your cargo bike was stolen"
    end
  end
end
