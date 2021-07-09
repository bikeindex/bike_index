require "rails_helper"

RSpec.describe BikeHelper, type: :helper do
  describe "bike_thumb_image" do
    context "bike photo exists" do
      it "returns the thumb path if one exists" do
        bike = Bike.new
        allow(bike).to receive(:thumb_path).and_return("pathy")
        allow(bike).to receive(:title_string).and_return("Title")
        expect(bike_thumb_image(bike)).to match(%r{img alt="Title"})
        expect(bike_thumb_image(bike)).to match(%r{src=".+images/pathy"})
      end
    end
    context "bike photo does not exist" do
      it "returns the bike placeholder path" do
        bike = Bike.new
        allow(bike).to receive(:title_string).and_return("Title")
        html = bike_thumb_image(bike)
        expect(html).to match("alt=\"Title\"")
        expect(html).to match('title=\"No image\"')
        expect(html).to match(/revised.bike_photo_placeholder.*\.svg/)
      end
    end
  end

  describe "title_html" do
    let(:bike) { Bike.new }
    it "returns expected thing" do
      expect(bike_title_html(bike)).to eq("<span><strong></strong></span>")
    end
    context "html frame_model" do
      let(:bike) { Bike.new(frame_model: "escape tags?</p>") }
      it "removes bs the HTML" do
        expect(bike_title_html(bike)).to eq("<span><strong></strong> escape tags?&lt;/p&gt;</span>")
      end
    end
    context "html frame_model" do
      let(:bike) { Bike.new(frame_model: "Bullit 'Love Ride'") }
      it "escapes the HTML" do
        expect(bike_title_html(bike)).to eq("<span><strong></strong> Bullit &#39;Love Ride&#39;</span>")
      end
    end
  end

  describe "bike_status_span" do
    let(:bike) { Bike.new(status: status) }
    let(:status) { "status_with_owner" }
    it "responds with nil" do
      expect(bike_status_span(bike)).to be_blank
    end
    context "unregistered parking notification" do
      let(:status) { "unregistered_parking_notification" }
      let(:target) { "<strong class=\"unregistered-color uppercase bike-status-html\">unregistered</strong>" }
      it "responds with unregistered" do
        expect(bike_status_span(bike)).to eq target
      end
    end
    context "stolen" do
      let(:status) { "status_stolen" }
      let(:target) { "<strong class=\"stolen-color uppercase bike-status-html\">stolen</strong>" }
      it "responds with strong" do
        expect(bike_status_span(bike)).to eq target
      end
    end
    context "impounded" do
      let(:status) { "status_impounded" }
      let(:target) { "<strong class=\"impounded-color uppercase bike-status-html\">impounded</strong>" }
      it "responds with strong" do
        expect(bike_status_span(bike)).to eq target
      end
    end
  end
end
