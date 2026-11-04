# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::EbikeRules::Results::Component, type: :component do
  include ActiveSupport::Testing::TimeHelpers

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

  it "renders a legal bike, its BikeBook photo, specs and certifications, and its state's law" do
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
      .and have_link("BikeBook", href: "/bikebook?vehicle_models=evc/us/in/electric_bicycle")
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
        .and have_css("[role='status'] li", text: "In Texas, it falls under Off-Highway Motorcycle.")
        .and have_css("button[aria-label='E-moto, not an e-bike'] + [role='tooltip'] h3", text: "Not an e-bike", visible: :all)
        .and have_css("[role='tooltip'] code", text: /\A\s*evc\/out_of_class\s*\z/, visible: :all)
    end
  end

  context "in a state that recognizes Class 1 alone" do
    let(:bike) { super().with(e_bike_class: 3, e_vehicle_classifications: ["evc/us/class_3"], top_assist_mph: 28, top_assist_kmh: 45) }
    let(:abbreviation) { "NJ" }

    it "names the state the class isn't recognized in, and the state's class it falls under with its rules, as an e-moto" do
      expect(component).to have_css("li", text: "Class 3 isn't recognized in New Jersey")
        .and have_css("[role='status'] li", text: "In New Jersey, it falls under Motorized Bicycle.")
        .and have_css("[role='status'] [role='button']", text: "Motorized Bicycle rules")
        .and have_css("[role='status'] > div > ul > li", text: /\A\s*Registered with the Motor Vehicle Commission[^.]*\s*\z/)
        .and have_css("[data-ui--collapse-target='content'] li", text: /Registered with the Motor Vehicle Commission.*N\.J\.S\.A\. 39:4-14\.3i/m)
        .and have_css("button[aria-label='E-moto, not an e-bike'] + [role='tooltip'] code", text: /\A\s*evc\/out_of_class\s*\z/, visible: :all)
        .and have_no_css("[role='img'][aria-label='Class 3 e-bike']")
    end
  end

  context "with an off-highway e-moto in California" do
    let(:bike) do
      super().with(e_bike_class: nil, e_vehicle_classifications: ["evc/off_highway_motorcycle"], watts: nil, top_assist_mph: nil, top_assist_kmh: nil,
        throttle: true, stock_throttle: true)
    end
    let(:abbreviation) { "CA" }

    it "bullets where it can go, with no citation, above its rules, which lead with them and a rider's, cited" do
      status = component.css("[role='status'] > div").first
      expect(status.css("> ul").first.css("li").map { it.text.strip }).to eq ["It isn't a Class 1, 2 or 3 e-bike. In California, it falls under Off-Highway Electric Motorcycle."]
      top_rules = status.css("> ul.tw\\:list-disc > li")
      expect(top_rules.map { it.text.strip }).to eq ["Ridden only in designated OHV areas or on private property; never on highways, streets, sidewalks, bike lanes or bike paths",
        "Can't be registered or converted for street use"]
      expect(top_rules.css("a")).to be_empty

      rules = status.css("[data-ui--collapse-target='content'] ul").first.css("li")
      expect(rules.map(&:text).first(4)).to match [a_string_including("Ridden only"), a_string_including("Can't be registered"),
        a_string_including("Identified with a California OHV Green Sticker"), a_string_including("No driver's license needed")]
      expect(rules.first.css("a").map(&:text)).to eq ["source"]
    end
  end

  context "with a Class 3 and a stock throttle in California, whose record names no state class" do
    let(:bike) do
      super().with(e_bike_class: 3, e_vehicle_classifications: ["evc/us/class_2", "evc/us/class_3"], watts: 750, top_assist_mph: 28, top_assist_kmh: 45,
        throttle: true, stock_throttle: true, throttle_mph: 20, throttle_kmh: 32)
    end
    let(:abbreviation) { "CA" }

    around { |example| travel_to(Time.zone.local(2026, 11, 4)) { example.run } }

    it "lists the rules of the class its speed and power fit, with the ones still to come dated" do
      expect(component).to have_css("[role='status'] li", text: "In California, it may fall under Moped.")
        .and have_css("[role='status'] [role='button']", text: "Moped rules")
        .and have_css("[role='status'] > div > ul > li", text: /\A\s*Riders need a driver's license with an M1 or M2[^§]*\z/)
        .and have_css("[data-ui--collapse-target='content'] li", text: /Riders need a driver's license with an M1 or M2.*§§12500, 12804\.9/m)
        .and have_css("[data-ui--collapse-target='content'] li", text: /A peace officer may remove it.*§22651\.08, added by AB 875/m)
        .and have_css("li", text: /From January 1, 2027:\s*Its maker, importer or seller must warn buyers.*§28191/m)
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
