require "rails_helper"

RSpec.describe Registrations::Show::Map::Component, type: :component do
  let(:options) { {latitude: 40.7, longitude: -73.9} }
  let(:component) { described_class.new(**options) }
  before { stub_const("MAPS_STYLE_URL", "https://maps.example.com/style.json") }

  it "renders the map container with the stimulus values and an unavailable fallback" do
    render_inline(component)
    node = page.find("div[data-controller='registrations--show--map']")
    expect(node["data-registrations--show--map-style-url-value"]).to eq "https://maps.example.com/style.json"
    expect(node["data-registrations--show--map-latitude-value"]).to eq "40.7"
    expect(node["data-registrations--show--map-longitude-value"]).to eq "-73.9"
    expect(node["data-registrations--show--map-radius-base-value"]).to eq "1.15"
    expect(node["data-registrations--show--map-point-value"]).to eq "false"
    expect(node).to have_css("[data-registrations--show--map-target='canvas']")
    # Shown by the controller when MapLibre/WebGL is unavailable
    expect(node).to have_css("p[hidden][data-registrations--show--map-target='unavailable']", text: "map couldn't be loaded", visible: :all)
  end

  context "precise (exact address public)" do
    let(:options) { {latitude: 40.7, longitude: -73.9, precise: true} }
    it "uses a larger radius base" do
      render_inline(component)
      expect(page.find("div[data-controller='registrations--show--map']")["data-registrations--show--map-radius-base-value"]).to eq "2"
    end
  end

  context "point (exact spot)" do
    let(:options) { {latitude: 40.7, longitude: -73.9, point: true} }
    it "marks the location as a point" do
      render_inline(component)
      expect(page.find("div[data-controller='registrations--show--map']")["data-registrations--show--map-point-value"]).to eq "true"
    end
  end

  context "missing coordinates" do
    let(:options) { {latitude: nil, longitude: nil} }
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
