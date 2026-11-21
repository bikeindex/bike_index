# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::EbikeRules::Reasons::Component, type: :component do
  before { stub_bikebook_catalog }

  let(:bike) do
    EbikeRuleServices::Bike.new(bikebook_id: "m/trek/2025/verve", manufacturer_name: "Trek", model: "Verve+ 2", first_year: 2025, vehicle_type: "bike",
      e_bike_class: 3, class_unknown: false, e_vehicle_classifications: ["evc/us/class-3"], optional_classes: {}, watts: 750, peak_watts: nil,
      top_assist_mph: 28, top_assist_kmh: 45, assists_past_kmh: nil, throttle: false, stock_throttle: false, throttle_mph: nil, throttle_kmh: nil,
      ul2849: :certified, ul2271: :unknown, photo_url: nil)
  end
  let(:abbreviation) { "CO" }
  let(:lookup) do
    EbikeRuleServices::Lookup.new(place: EbikeRuleServices::Places.find("US-#{abbreviation}"), detected_place: nil, bikebook_id: bike.bikebook_id,
      manual: false, manual_top_speed: 28, manual_watts: nil, manual_throttle: false, manual_throttle_speed: nil, bike:, errors: [], submitted: true)
  end
  let(:component) { render_inline(described_class.new(lookup:, frame_id: "ebike-rules-reasons-overview-m-trek-2025-verve")) }

  it "is an empty frame for an e-bike" do
    expect(component).to have_css("turbo-frame#ebike-rules-reasons-overview-m-trek-2025-verve")
      .and have_no_css("p")
  end

  context "in a state that doesn't recognize its class" do
    let(:abbreviation) { "NJ" }

    it "says so, and what's over the state's limits" do
      expect(component).to have_css("turbo-frame p", exact_text: "Class 3 isn't recognized in New Jersey. Assists to 28 mph, over the 20 mph limit.")
    end
  end

  context "with an e-moto" do
    let(:bike) do
      super().with(e_bike_class: nil, e_vehicle_classifications: ["evc/off-highway-motorcycle"], watts: 12_500, top_assist_mph: nil,
        throttle: true, stock_throttle: true, throttle_mph: 59)
    end

    it "says what's over the state's limits, as its tiles say it's in no class" do
      expect(component).to have_css("turbo-frame p", exact_text: "12,500W motor exceeds the 750W cap. Throttle runs to 59 mph, over the 28 mph limit.")
    end

    context "without a state" do
      let(:lookup) { super().with(place: nil, errors: [:state]) }

      it "says what's over the US classes' limits" do
        expect(component).to have_css("turbo-frame p", exact_text: "12,500W motor exceeds the 750W cap. Throttle runs to 59 mph, over the 28 mph limit.")
      end
    end
  end

  context "with an e-bike, without a state" do
    let(:lookup) { super().with(place: nil, errors: [:state]) }

    it "is an empty frame" do
      expect(component).to have_css("turbo-frame").and have_no_css("p")
    end
  end

  context "with a Class 3 and a throttle in California" do
    let(:abbreviation) { "CA" }
    let(:bike) do
      super().with(e_vehicle_classifications: ["evc/us/class-2", "evc/us/class-3"], throttle: true, stock_throttle: true, throttle_mph: 20)
    end

    it "says its classes aren't permitted, and why" do
      expect(component).to have_css("turbo-frame p",
        exact_text: "It is a Class 2 and Class 3 e-bike, which is not permitted. Assists to 28 mph, not allowed with a throttle.")
    end

    context "that's optional" do
      let(:bike) { super().with(stock_throttle: false, optional_classes: {2 => "throttle"}) }

      it "says it's legal only without it" do
        expect(component).to have_css("turbo-frame p", exact_text: "It's legal only without its optional throttle.")
      end
    end
  end
end
