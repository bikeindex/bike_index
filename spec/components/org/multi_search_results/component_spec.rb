# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::MultiSearchResults::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:serial) { "SERIAL111" }
  let(:serial_chip_id) { "chip_0" }
  let(:interpreted_params) { {} }
  let(:per_page) { 10 }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(described_class.new(
        organization:, query: serial, chip_id: serial_chip_id, pagy:, bikes:,
        interpreted_params:, per_page:, close_serials:
      ))
    end
  end

  context "with matching bikes" do
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let(:bikes) { [bike] }
    let(:pagy) { Pagy::Offset.new(count: 1, page: 1, limit: 10) }
    let(:close_serials) { nil }

    it "renders result with serial header and table" do
      expect(component).to have_css(".multi-search-serial-result#result_0")
      expect(component).to have_css("span.serial-span", text: serial)
      expect(component).to have_text("1 result")
      expect(component).to have_css("table")
    end

    context "with more than 10 results" do
      let(:pagy) { Pagy::Offset.new(count: 25, page: 1, limit: 10) }

      it "shows view all link" do
        expect(component).to have_text("first 10 shown")
        expect(component).to have_link("view all")
      end
    end
  end

  context "with no matching bikes" do
    let(:bikes) { [] }
    let(:pagy) { Pagy::Offset.new(count: 0, page: 1, limit: 10) }
    let(:close_serials) { nil }

    it "renders no matches message" do
      expect(component).to have_css(".multi-search-serial-result[data-result-count='0']")
      expect(component).to have_text("No matches found")
      expect(component).not_to have_css("table")
    end
  end

  context "with close serials" do
    let(:close_bike) { FactoryBot.create(:bike, serial_number: "SERIAL112") }
    let(:bikes) { [] }
    let(:pagy) { Pagy::Offset.new(count: 0, page: 1, limit: 10) }
    let(:close_serials) { [close_bike] }

    it "renders close serial suggestions" do
      expect(component).to have_text("No exact matches")
      expect(component).to have_link("SERIAL112")
    end
  end
end
