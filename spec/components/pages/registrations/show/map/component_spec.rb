require "rails_helper"

RSpec.describe Pages::Registrations::Show::Map::Component, type: :component do
  let(:options) { {latitude: 40.7, longitude: -73.9} }
  let(:component) { described_class.new(**options) }

  it "renders the map container with the stimulus values and an unavailable fallback" do
    render_inline(component)
    node = page.find("div[data-controller='registrations--show--map']")
    expect(node["data-registrations--show--map-latitude-value"]).to eq "40.7"
    expect(node["data-registrations--show--map-longitude-value"]).to eq "-73.9"
    expect(node["data-registrations--show--map-radius-meters-value"]).to eq "1000"
    expect(node["data-registrations--show--map-point-value"]).to eq "false"
    expect(node).to have_css("[data-registrations--show--map-target='canvas']")
    # Shown by the controller when MapLibre/WebGL is unavailable
    expect(node).to have_css("p[hidden][data-registrations--show--map-target='unavailable']", text: "map couldn't be loaded", visible: :all)
  end

  context "precise (exact address public)" do
    let(:options) { {latitude: 40.7, longitude: -73.9, precise: true} }
    it "uses a tighter radius" do
      render_inline(component)
      expect(page.find("div[data-controller='registrations--show--map']")["data-registrations--show--map-radius-meters-value"]).to eq "250"
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
