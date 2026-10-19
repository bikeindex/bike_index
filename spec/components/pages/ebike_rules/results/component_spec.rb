# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::EbikeRules::Results::Component, type: :component do
  before { stub_bikebook_catalog }

  let(:bike) do
    EbikeRuleServices::Bike.new(bikebook_id: "m/trek/2025/verve", manufacturer_name: "Trek", model: "Verve+ 2", first_year: 2025, vehicle_type: "bike",
      e_bike_class: 1, class_unknown: false, e_vehicle_classifications: [], optional_classes: {}, watts: 250, peak_watts: nil, top_assist_mph: 20,
      top_assist_kmh: 32, assists_past_kmh: nil, throttle: false, stock_throttle: false, throttle_mph: nil, throttle_kmh: nil, ul2849: :certified, ul2271: :unknown, photo_url: "https://bikebook.bikeindex.org/trek/2025/verve.jpg")
  end
  let(:abbreviation) { "IN" }
  let(:code) { "US-#{abbreviation}" }
  let(:lookup) do
    EbikeRuleServices::Lookup.new(place: EbikeRuleServices::Places.find(code), detected_place: nil, bikebook_id: bike.bikebook_id,
      manual: false, manual_top_speed: 20, manual_watts: nil, manual_throttle: true, bike:, errors: [], submitted: true)
  end
  let(:component) { render_inline(described_class.new(lookup:)) }

  it "renders a legal bike, its Bike Book photo, specs and certifications, and its state's law" do
    expect(component).to have_css("[role='status']", text: "Legal to ride")
      .and have_css("[role='status']", text: "Your Trek Verve+ 2 is legal to ride in Indiana as a Class 1 e-bike.")
      .and have_css("img[src='https://bikebook.bikeindex.org/trek/2025/verve.jpg'][alt='Trek Verve+ 2']")
      .and have_css("[role='img'][aria-label='Class 1 e-bike']")
      .and have_css("p", text: /\A\s*2025 model\s*\z/)
      .and have_css("dd", text: "Not provided", count: 0)
      # the certification it carries alone, without the one it's not known to
      .and have_text("UL 2849 Certified")
      .and have_no_text("UL 2271")
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
        .and have_css("[role='status']", text: "Your e-bike is legal to ride in Colorado as a Class 2 and 3 e-bike, with 1 rule to check.")
        .and have_css("[role='status'] li", text: "Throttle must cut out at 20 mph.")
        .and have_css("p", text: /\A\s*Entered manually\s*\z/)
        .and have_css("dd", text: "28 mph")
        .and have_text("Entered by you, not verified by BikeBook.")
        .and have_text("Certification unknown").and have_no_text("E-bike electrical system")
        .and have_no_css("img")
    end
  end

  context "with an e-moto" do
    let(:bike) do
      super().with(e_bike_class: nil, e_vehicle_classifications: ["evc/us/ca/off_highway_electric_motorcycle"], watts: 12_500,
        top_assist_mph: nil, throttle: true, stock_throttle: true)
    end
    let(:abbreviation) { "TX" }

    it "names what the state classes it as" do
      expect(component).to have_css("[role='status']", text: "Not permitted")
        .and have_css("[role='status'] li", text: "12,500W motor exceeds the 750W cap.")
        .and have_css("[role='status'] li", text: "In Texas, it falls under Off-Highway Motorcycle, which can require registration and a license.")
        .and have_css("button[aria-label='E-moto, not an e-bike'] + [role='tooltip'] h3", text: "Not an e-bike", visible: :all)
    end
  end

  context "in a Canadian province" do
    let(:code) { "CA-ON" }

    it "checks its law's limits in km/h, with nothing of the US's classes" do
      expect(component).to have_css("[role='status']", text: "Your Trek Verve+ 2 is legal to ride in Ontario under the Power-Assisted Bicycle rules.")
        .and have_css("li", text: /Top assisted speed\s*32 km\/h\s*Assists to 32 km\/h, within the limit/)
        .and have_css("dd", text: "32 km/h")
        .and have_text("Your province or territory")
        .and have_text("Riders must be 16 or older")
        .and have_text("catalog of e-bike law")
        .and have_no_css("[role='img'][aria-label='Class 1 e-bike']")
        .and have_no_text("Classes recognized")
        .and have_no_text("mph")
    end

    context "with a motor over its cap" do
      let(:bike) { super().with(watts: 750, throttle: true, stock_throttle: true, throttle_kmh: 32) }

      it "isn't permitted" do
        expect(component).to have_css("[role='status']", text: "Your Trek Verve+ 2 is not permitted as an e-bike under current Ontario rules.")
          .and have_css("[role='status'] li", text: "750W motor exceeds the 500W cap.")
          .and have_css("[role='status'] li", text: "which can require registration and a licence.")
          .and have_css("dd", text: "Yes, to 32 km/h")
      end
    end

    context "with no e-bike law, where an e-bike falls in with a motor vehicle" do
      let(:code) { "CA-NB" }

      it "may be legal under that vehicle's rules, with its licence and registration to check" do
        expect(component).to have_css("[role='status']", text: "Your Trek Verve+ 2 may be legal to ride in New Brunswick under the Motor Driven Cycle rules, " \
          "with 1 rule to check.")
          .and have_css("li", text: /Regulated as\s*Motor Driven Cycle\s*There's no e-bike category here/)
          .and have_css("li", text: "Registered with one plate")
      end
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
