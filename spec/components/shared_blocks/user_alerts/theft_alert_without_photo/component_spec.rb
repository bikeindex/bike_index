# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::UserAlerts::TheftAlertWithoutPhoto::Component, type: :component do
  let(:bikes) { [Bike.new(id: 12, mnfg_name: "Surly", frame_model: "Cross Check", year: 2018)] }
  let(:component) { render_inline(described_class.new(bikes:)) }

  it "doesn't render without bikes" do
    expect(described_class.new(bikes: []).render?).to be_falsey
  end

  it "opens on load, linking each bike to its photos" do
    modal = component.css("dialog#theft-alert-missing-photo")
    expect(modal.first["data-ui--modal-open-on-connect-value"]).to eq "true"
    expect(modal.text).to include "Please add a photo"
    link = modal.css("a").first
    expect(link[:href]).to eq "/bikes/12/edit/photos"
    expect(link.text).to include "2018 Surly Cross Check"
  end

  # Dismissing the modal would otherwise be the end of it, so the banner carries the same
  # thing rather than pointing back at it
  it "renders a banner outside the modal, saying everything the modal does" do
    banner = component.css("[role='alert']").reject { |el| el.ancestors("dialog").any? }.first
    expect(banner.text).to include "Please add a photo"
    expect(banner.text).to include "Successful promoted alerts"
    expect(banner.text).to include "2018 Surly Cross Check"
    expect(banner.css("a").map { |a| a[:href] }).to eq ["/bikes/12/edit/photos"]
  end

  context "with a cargo bike" do
    let(:bikes) { [Bike.new(id: 12, cycle_type: :cargo)] }

    it "describes the cycle type" do
      expect(component.text).to include "any photos of your cargo bike"
    end
  end
end
