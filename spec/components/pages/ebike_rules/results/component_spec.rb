# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::EbikeRules::Results::Component, type: :component do
  let(:bike) do
    EbikeRules::Bike.new(bikebook_id: "m/trek/2025/verve", manufacturer_name: "Trek", model: "Verve+ 2", first_year: 2025,
      e_bike_class: 1, watts: 250, top_assist_mph: 20, throttle: false, throttle_mph: nil, ul2849: :certified,
      ul2271: :unknown, photo_url: "https://bikebook.bikeindex.org/trek/2025/verve.jpg")
  end
  let(:abbreviation) { "IN" }
  let(:lookup) do
    EbikeRules::Lookup.new(state: EbikeRules::StateLaws.state(abbreviation), detected_state: nil, bikebook_id: bike.bikebook_id,
      manual: false, manual_class: 2, manual_watts: nil, manual_throttle: true, bike:, errors: [], submitted: true)
  end
  let(:component) { render_inline(described_class.new(lookup:)) }

  it "renders a legal bike, its Bike Book photo, specs and certifications, and its state's rules" do
    expect(component).to have_css("[role='status']", text: "Legal to ride")
      .and have_css("[role='status']", text: "Your Trek Verve+ 2 is legal to ride in Indiana as a Class 1 e-bike.")
      .and have_css("img[src='https://bikebook.bikeindex.org/trek/2025/verve.jpg'][alt='Trek Verve+ 2']")
      .and have_css("[role='img'][aria-label='Class 1 e-bike']")
      .and have_text("2025 model · Bike Book")
      .and have_css("dd", text: "Not provided", count: 0)
      .and have_text("UL 2849 Certified")
      .and have_text("UL 2271 status unknown")
      .and have_css("li", text: "No minimum age for Class 1")
      .and have_css("li [role='img'][aria-label='Meets this rule']", count: 7)
      .and have_text("Source: state law last reviewed 2026-Q3.")
    # a statute is a click away, rendered collapsed
    expect(component).to have_css("#statute-age.tw\\:hidden a[href='https://iga.in.gov/laws/2024/ic/titles/9'][target='_blank']",
      text: "IC 9-21-11-13.1")
    expect(component).to have_css("[data-ui--copy-button-text-value='http://test.host/ebike-rules#state-in']")
  end

  context "with a bike entered by hand" do
    let(:bike) { EbikeRules::Bike.manual(e_bike_class: 3, watts: 750, throttle: true) }
    let(:abbreviation) { "CA" }

    it "renders the rules to check, with no photo and unknown certifications" do
      expect(component).to have_css("[role='status']", text: "Legal, with rules to check")
        .and have_css("[role='status']", text: "Your e-bike is legal to ride in California as a Class 3 e-bike, with 4 rules to check.")
        .and have_css("[role='status'] li", text: "Throttle must cut out at 20 mph.")
        .and have_text("Entered manually · Class 3")
        .and have_css("dd", text: "Not provided")
        .and have_text("Entered by you, not verified by Bike Book.")
        .and have_no_css("img")
    end
  end

  context "without the state's rules on file" do
    let(:abbreviation) { "TX" }

    it "says so" do
      expect(component).to have_css("[role='status']", text: "Rules not on file")
        .and have_css("[role='status'] li", text: "Your Trek Verve+ 2 is listed as a Class 1 e-bike. Check the Texas DMV for local rules.")
        .and have_text("We're still reviewing Texas's rules.")
        .and have_no_css("li [role='img']")
    end
  end
end
