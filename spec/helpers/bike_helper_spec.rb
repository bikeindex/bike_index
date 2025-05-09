require "rails_helper"

RSpec.describe BikeHelper, type: :helper do
  describe "render_serial_display" do
    let(:bike) { Bike.new(serial_number: serial_number, cycle_type: "tandem") }
    let(:serial_number) { "fff333" }
    it "is in a code element" do
      expect(render_serial_display(bike)).to eq("<code class=\"bike-serial\">FFF333</code>")
    end
    context "unknown" do
      let(:serial_number) { "unknown" }
      it "is in a span element" do
        expect(render_serial_display(bike)).to eq("<span class=\"less-strong\">unknown</span>")
      end
    end
    context "hidden" do
      let(:target) { "<span class=\"less-strong\">hidden</span> <em class=\"small less-less-strong\">because tandem is impounded</em>" }
      let(:target_authorized) { "<code class=\"bike-serial\">FFF333</code> <em class=\"small less-less-strong\">hidden for unauthorized users</em>" }
      it "returns target" do
        bike.status = "status_impounded"
        expect(render_serial_display(bike)).to eq target
        expect(render_serial_display(bike, skip_explanation: true)).to eq "<span class=\"less-strong\">hidden</span>"
        expect(render_serial_display(bike, User.new)).to eq target
        expect(render_serial_display(bike, User.new(superuser: true))).to eq target_authorized
        expect(render_serial_display(bike, User.new(superuser: true), skip_explanation: true)).to eq "<code class=\"bike-serial\">FFF333</code>"
      end
    end
  end

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
    context "quotes" do
      let(:bike) { Bike.new(frame_model: "Bullit 'Love Ride'") }
      let(:target) { "<span><strong></strong> Bullit &#39;Love Ride&#39;</span>" }
      it "escapes the HTML" do
        expect(bike_title_html(bike)).to eq target
        expect(bike_title_html(bike, include_status: true)).to eq target
      end
    end
    context "year and cycle_type and status" do
      let(:bike) { Bike.new(frame_model: '"Love Ride"', cycle_type: "trailer", year: 2020, status: "status_stolen", mnfg_name: "Bullit") }
      let(:target_no_span) { "<strong>2020 Bullit</strong> &quot;Love Ride&quot;<em> Bike Trailer</em></span>" }
      it "escapes the HTML" do
        expect(bike_title_html(bike)).to eq "<span>#{target_no_span}"
        expect(bike_title_html(bike, include_status: false)).to eq "<span>#{target_no_span}"
        expect(bike_title_html(bike, include_status: true)).to eq "<span>#{bike_status_span(bike)} #{target_no_span}"
      end
    end
  end

  describe "bike_status_span" do
    let(:bike) { Bike.new(status: status) }
    let(:status) { "status_with_owner" }
    it "responds with nil" do
      expect(bike_status_span(bike)).to be_blank
    end
    context "is_for_sale" do
      before { bike.is_for_sale = true }
      let(:target) { "<strong class=\"for-sale-color uppercase bike-status-html\">for sale</strong>" }
      it "responds with strong" do
        expect(bike.status_humanized).to eq "for sale"
        expect(bike_status_span(bike)).to eq target
      end
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
      context "found" do
        let(:target) { "<strong class=\"found-color uppercase bike-status-html\">found</strong>" }
        it "responds with found" do
          allow(bike).to receive(:status_found?).and_return(true)
          expect(bike_status_span(bike)).to eq target
        end
      end
    end
    context "found" do
      let(:status) { "status_abandoned" }
      let(:target) { "<strong class=\"abandoned-color uppercase bike-status-html\">abandoned</strong>" }
      it "responds with strong" do
        expect(bike_status_span(bike)).to eq target
      end
    end
  end
end
