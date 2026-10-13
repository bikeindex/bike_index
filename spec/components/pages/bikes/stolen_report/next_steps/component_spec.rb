# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Bikes::StolenReport::NextSteps::Component, type: :component do
  let(:component) do
    render_inline(described_class.new(bike:, stolen_record: bike.current_stolen_record, register_another_path: "/register/new"))
  end
  let(:bike) { FactoryBot.create(:stolen_bike_in_chicago) }

  it "leaves the police services to do until there's a report, and offers the alert" do
    expect(component).to have_link("Add report")
    expect(component).to have_text("Sent to LEADSonline when you add your police report number")
    expect(component).to have_no_text("requires a serial number")
    expect(component).to have_no_text("Add the serial number")
    expect(component).to have_no_text("File a police report")
    expect(component).to have_link("See alert options")
  end

  context "with several Promoted Theft Alert plans" do
    before do
      FactoryBot.create(:theft_alert_plan, amount_cents: 4_999)
      FactoryBot.create(:theft_alert_plan, amount_cents: 1_999)
      # Cheaper, but not for sale here
      FactoryBot.create(:theft_alert_plan, amount_cents: 999, active: false)
      FactoryBot.create(:theft_alert_plan, amount_cents: 499, language: "nl")
    end

    it "starts from the lowest price on sale" do
      expect(component.text.squish).to include("From $19.99")
    end
  end

  context "without a serial" do
    let(:bike) { FactoryBot.create(:stolen_bike_in_chicago, serial_number: "unknown") }

    it "asks for it, since the police services need it" do
      expect(component).to have_link("Add serial", href: "/bikes/#{bike.id}/edit/bike_details")
      expect(component).to have_text("(requires a serial number)", count: 2)
    end
  end

  context "stolen in the Netherlands" do
    let(:bike) { FactoryBot.create(:stolen_bike_in_amsterdam) }

    it "says how to file the police report there" do
      expect(component).to have_text("File a police report")
      expect(component).to have_link("www.politie.nl/mijn-buurt/politiebureaus")
    end

    context "with the police report" do
      before { bike.current_stolen_record.update(police_report_number: "XX-1") }

      it "has nothing left to say about filing it" do
        expect(component).to have_text("Police report added")
        expect(component).to have_no_text("File a police report")
      end
    end
  end

  context "with a Promoted Theft Alert bought" do
    before { FactoryBot.create(:theft_alert_paid, stolen_record: bike.current_stolen_record) }

    it "points to it rather than selling another" do
      expect(component).to have_text("Promoted Theft Alert is purchased")
      expect(component).to have_link("View your alerts", href: "/bikes/#{bike.id}/theft_alert/new")
      expect(component).to have_no_link("See alert options")
    end
  end

  context "with a Promoted Theft Alert checkout abandoned" do
    before { FactoryBot.create(:theft_alert_unpaid, stolen_record: bike.current_stolen_record) }

    it "still offers one" do
      expect(component).to have_no_text("Promoted Theft Alert is purchased")
      expect(component).to have_link("See alert options")
    end
  end

  context "stolen without a city" do
    before { bike.current_stolen_record.update_columns(city: nil) }

    it "shares the theft without one" do
      body = CGI.parse(URI(component.at_css("a[href^='https://nextdoor.com']")["href"]).query)["body"].first
      expect(body).to start_with("Stolen: #{bike.title_string}. Please keep an eye out!")
    end
  end
end
