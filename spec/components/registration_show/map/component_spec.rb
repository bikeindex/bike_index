require "rails_helper"

RSpec.describe RegistrationShow::Map::Component, type: :component do
  let(:options) { {latitude: 40.7, longitude: -73.9, mapbox_key: "pk.test"} }
  let(:component) { described_class.new(**options) }

  it "renders the map container with the stimulus values" do
    render_inline(component)
    node = page.find("div[data-controller='registration-show--map']")
    expect(node["data-registration-show--map-api-key-value"]).to eq "pk.test"
    expect(node["data-registration-show--map-latitude-value"]).to eq "40.7"
    expect(node["data-registration-show--map-longitude-value"]).to eq "-73.9"
    expect(node["data-registration-show--map-radius-base-value"]).to eq "1.15"
  end

  context "precise (exact address public)" do
    let(:options) { {latitude: 40.7, longitude: -73.9, mapbox_key: "pk.test", precise: true} }
    it "uses a larger radius base" do
      render_inline(component)
      expect(page.find("div")["data-registration-show--map-radius-base-value"]).to eq "2"
    end
  end

  context "missing coordinates" do
    let(:options) { {latitude: nil, longitude: nil, mapbox_key: "pk.test"} }
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "missing mapbox_key" do
    let(:options) { {latitude: 40.7, longitude: -73.9, mapbox_key: nil} }
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "placeholder mapbox_key (not a real pk. token)" do
    let(:options) { {latitude: 40.7, longitude: -73.9, mapbox_key: "PLACEHOLDER-REPLACE-BEFORE-DEPLOY"} }
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
