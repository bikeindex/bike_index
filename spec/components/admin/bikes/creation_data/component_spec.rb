# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::CreationData::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:)) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }

  # display_dev_info? is always false in test, so this is the collapsed rendering
  it "renders the ownership collapsed behind a stimulus trigger" do
    expect(component.css("[data-controller=ui--collapse]")).to be_present
    expect(component.css("[data-action='ui--collapse#toggle']").text).to eq "Creation data & developer information"

    content = component.css("[data-ui--collapse-target=content]").first
    expect(content["class"]).to include("tw:hidden")
    expect(content.text).to match(/Ownership/)
    expect(content.text).to match(/No BParams exist/)
  end

  it "doesn't render the bootstrap collapse hooks it replaced" do
    expect(component.css("[data-toggle=collapse]")).to be_blank
    expect(component.css(".collapse")).to be_blank
    # BParamsView is still the CodeRay styling hook
    expect(component.css("#BParamsView")).to be_present
  end

  context "with b_params" do
    let!(:b_param) { FactoryBot.create(:b_param, created_bike_id: bike.id, params: {bike: {serial_number: "cool serial"}}) }

    it "renders them" do
      expect(component.text).to match(/BParam/)
      expect(component.text).to include("cool serial")
    end
  end
end
