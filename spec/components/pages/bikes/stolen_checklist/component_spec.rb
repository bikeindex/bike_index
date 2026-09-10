# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Bikes::StolenChecklist::Component, type: :component do
  let(:bike) { FactoryBot.create(:stolen_bike_in_chicago) }
  let(:stolen_record) { bike.current_stolen_record }
  let(:component) { render_inline(described_class.new(bike:, stolen_record:)) }

  def item_texts(selector) = component.css(selector).map { it.text.squish }

  it "ticks off what the registration already did, and links to what's left" do
    expect(component).to have_css("ul.stolen-checklist")
    expect(item_texts("li.completed-item > .checklist-text"))
      .to eq ["List bike on Bike Index", "Report theft on Bike Index, including location where the theft occurred"]
    # The tick is the checkbox's, so the text beside it reads on its own
    expect(item_texts("li.completed-item > .checklist-checkbox")).to eq %w[✓ ✓]
    expect(component).to have_link("a photo of your bike")
    expect(component).to have_link("your Police Report Number")
    # Nothing to say about a serial this bike has
    expect(component).to have_no_text("CRITICAL")
  end

  context "without a location" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    it "renders nothing - there's no checklist until the theft has one" do
      expect(stolen_record.display_checklist?).to be_falsey
      expect(component.to_html).to be_blank
    end
  end

  context "with a police report number" do
    before { stolen_record.update(police_report_number: "8675309") }

    it "ticks it, and the services the number is what sends it to" do
      done = item_texts("li.completed-item > .checklist-text")
      expect(done.any? { it.include?("Add your Police Report Number") }).to be_truthy
      expect(done.any? { it.include?("LEADSonline") }).to be_truthy
      expect(component).to have_no_text("requires a serial number")
    end

    context "without a serial" do
      let(:bike) { FactoryBot.create(:stolen_bike_in_chicago, serial_number: "unknown") }

      # The services search on the serial, so a report without one isn't sent
      it "asks for the serial and says what it's holding up" do
        expect(component).to have_text("CRITICAL")
        expect(component.css(".tw\\:text-red-600").count).to eq 2
        expect(item_texts("li.completed-item > .checklist-text").any? { it.include?("LEADSonline") })
          .to be_falsey
      end
    end
  end

  context "in the Netherlands" do
    let(:bike) { FactoryBot.create(:stolen_bike_in_amsterdam) }

    it "adds the ways of reporting it there" do
      expect(component).to have_text("File a Police report!")
      expect(component).to have_link("at this politie.nl webpage")
      expect(component).to have_text("call 0900-8844")
    end
  end
end
