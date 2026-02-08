# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::BikeCell::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {bike:, bike_id:, bike_link_path:, search_url:, render_search:} }
  let(:bike) { nil }
  let(:bike_id) { nil }
  let(:bike_link_path) { nil }
  let(:search_url) { nil }
  let(:render_search) { nil }

  context "with a bike" do
    let(:bike) { FactoryBot.create(:bike, frame_model: "FX 3") }

    it "renders colors, manufacturer, and model" do
      expect(component.css("strong").text).to eq bike.mnfg_name
      expect(component.css("em").text).to eq "FX 3"
      expect(component.text).to include(bike.frame_colors.to_sentence)
    end

    context "with bike_link_path" do
      let(:bike_link_path) { "/admin/bikes/#{bike.id}" }

      it "renders a link to the bike" do
        expect(component.css("a[href='#{bike_link_path}']")).to be_present
      end
    end

    context "with bike_link_path set to false" do
      let(:bike_link_path) { false }

      it "does not render a link" do
        expect(component.css("a")).to be_blank
      end
    end

    context "non-bike cycle_type" do
      let(:bike) { FactoryBot.create(:bike, cycle_type: "cargo") }

      it "renders the type" do
        expect(component.css("small").text).to include(bike.type)
      end
    end

    context "with thumb_path" do
      it "renders camera emoji" do
        allow(bike).to receive(:thumb_path).and_return("http://example.com/thumb.jpg")
        rendered = render_inline(described_class.new(bike:))
        expect(rendered.text).to include("📷")
      end
    end

    context "unregistered_parking_notification" do
      let(:bike) { FactoryBot.create(:bike, status: "unregistered_parking_notification") }

      it "renders unregistered tag" do
        expect(component.css("em.text-warning").text).to include("unregistered")
      end
    end

    context "with creation_description" do
      let(:bike) { FactoryBot.create(:bike_lightspeed_pos) }

      it "renders origin with title" do
        expect(bike.creation_description).to eq "Lightspeed"
        expect(component.css("small.less-strong span").text).to eq "Lightspeed"
        expect(component.css("small.less-strong span").first["title"]).to eq "Automatically registered by bike shop point of sale (Lightspeed POS)"
      end
    end
  end

  context "with missing bike" do
    let(:bike_id) { 99999999 }

    it "renders missing bike message" do
      expect(component.text).to match(/Missing bike/)
      expect(component.text).to match(/99999999/)
    end
  end

  context "with render_search" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:render_search) { true }
    let(:search_url) { "/admin/bikes?search_bike_id=#{bike.id}" }

    it "renders search link" do
      expect(component.css("a.display-sortable-link")).to be_present
    end
  end
end
