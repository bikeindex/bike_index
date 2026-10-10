# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::EbikeRules::Results::Component, type: :component do
  before { stub_bikebook_catalog }

  let(:bike) do
    EbikeRuleServices::Bike.new(bikebook_id: "m/trek/2025/verve", manufacturer_name: "Trek", model: "Verve+ 2", first_year: 2025,
      e_bike_class: 1, class_unknown: false, e_vehicle_classifications: [], watts: 250, peak_watts: nil, top_assist_mph: 20, throttle: false, throttle_mph: nil,
      ul2849: :certified, ul2271: :unknown, photo_url: "https://bikebook.bikeindex.org/trek/2025/verve.jpg")
  end
  let(:abbreviation) { "IN" }
  let(:lookup) do
    EbikeRuleServices::Lookup.new(state: EbikeRuleServices::StateLaws.state(abbreviation), detected_state: nil, bikebook_id: bike.bikebook_id,
      manual: false, manual_mph: 20, manual_watts: nil, manual_throttle: true, bike:, errors: [], submitted: true)
  end
  let(:component) { render_inline(described_class.new(lookup:)) }

  it "renders a legal bike, its Bike Book photo, specs and certifications, and its state's law" do
    expect(component).to have_css("[role='status']", text: "Legal to ride")
      .and have_css("[role='status']", text: "Your Trek Verve+ 2 is legal to ride in Indiana as a Class 1 e-bike.")
      .and have_css("img[src='https://bikebook.bikeindex.org/trek/2025/verve.jpg'][alt='Trek Verve+ 2']")
      .and have_css("[role='img'][aria-label='Class 1 e-bike']")
      .and have_text("2025 model · BikeBook")
      .and have_css("dd", text: "Not provided", count: 0)
      .and have_text("UL 2849 Certified")
      .and have_text("UL 2271 status unknown")
      .and have_css("li", text: /Classes recognized\s*Classes 1, 2, and 3\s*Class 1 is recognized/)
      .and have_css("li [role='img'][aria-label='Meets this rule']", count: 4)
      .and have_css("li", text: "Class 3 riders must be 15 or older")
      .and have_link(href: "https://in.gov/dnr/rules-and-regulations/e-bike-rules")
      .and have_link("BikeBook", href: "/bikebook?vehicle_models=evc%2Fus%2Fin%2Felectric_bicycle")
      .and have_link("Register on Bike Index — free", href: "/register/new?frame_model=Verve%2B+2&manufacturer=Trek")
  end

  context "with a bike entered by hand" do
    let(:bike) { EbikeRuleServices::Bike.manual(top_mph: 28, watts: 750, throttle: true) }
    let(:abbreviation) { "CO" }

    it "renders the rule to check, with no photo and unknown certifications" do
      expect(component).to have_css("[role='status']", text: "Legal, with rules to check")
        .and have_css("[role='status']", text: "Your e-bike is legal to ride in Colorado as a Class 3 e-bike, with 1 rule to check.")
        .and have_css("[role='status'] li", text: "Throttle must cut out at 20 mph.")
        .and have_text("Entered manually · Class 3")
        .and have_css("dd", text: "28 mph")
        .and have_text("Entered by you, not verified by BikeBook.")
        .and have_no_css("img")
    end
  end

  context "with an e-moto" do
    let(:bike) do
      super().with(e_bike_class: nil, e_vehicle_classifications: ["evc/us/ca/off_highway_electric_motorcycle"], watts: 12_500,
        top_assist_mph: nil, throttle: true)
    end
    let(:abbreviation) { "TX" }

    it "names what the state classes it as" do
      expect(component).to have_css("[role='status']", text: "Not permitted")
        .and have_css("[role='status'] li", text: "12,500W motor exceeds the 750W cap.")
        .and have_css("[role='status'] li", text: "In Texas, it falls under Off-Highway Motorcycle, which can require registration and a license.")
    end
  end

  context "without the state's rules on file" do
    let(:abbreviation) { "WY" }

    it "says so" do
      expect(component).to have_css("[role='status']", text: "Rules not on file")
        .and have_css("[role='status'] li", text: "Your Trek Verve+ 2 is listed as a Class 1 e-bike. Check the Wyoming DMV for local rules.")
        .and have_text("We're still reviewing Wyoming's rules.")
        .and have_no_css("li [role='img']")
    end
  end
end
