# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::SearchResults::BikeCard::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:, organization:, search_all:)) }
  let(:organization) { FactoryBot.create(:organization) }
  let(:search_all) { false }
  let(:color) { FactoryBot.create(:color, name: "Purple", display: "#715eb2") }
  let(:bike) do
    FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization,
      manufacturer: FactoryBot.create(:manufacturer, name: "Surly"), frame_model: "Midnight Special",
      primary_frame_color: color, serial_number: "SUR-77120934")
  end

  it "renders the bike linking to its org page, with its status, colors, type and serial" do
    expect(component).to have_link(href: "/bikes/#{bike.id}?organization_id=#{organization.to_param}")
    expect(component).to have_css("strong", text: "Surly")
    expect(component).to have_text("Midnight Special")
    expect(component).to have_text("Stolen ·")
    expect(component).to have_css("span.localizeTime")
    expect(component).to have_text("Purple")
    expect(component).to have_text("Bike")
    expect(component).to have_text("SUR-77120934")
    expect(component).not_to have_text("Registered with")
  end

  context "with search_all" do
    let(:search_all) { true }

    it "says it's registered with the organization" do
      expect(component).to have_text("Registered with #{organization.short_name}")
    end

    context "when it isn't registered with the organization" do
      let(:bike) { FactoryBot.create(:bike, propulsion_type: "throttle", cycle_type: "cargo") }

      it "says so, and marks it an e-vehicle" do
        expect(component).to have_text("Not registered with #{organization.short_name}")
        expect(component).to have_css("[role=tooltip]", text: "E-vehicle", visible: :all)
        expect(component).to have_text("Cargo")
      end
    end
  end

  context "with caching", :caching do
    include_context :caching_basic

    let(:listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let(:bike) { listing.item }

    def render_card(search_all: false)
      with_controller_class(ApplicationController) do
        render_inline(described_class.new(bike: bike.reload, organization:, search_all:))
      end
    end

    it "caches the card per organization and search_all, and rewrites it when the price changes" do
      keys = fragments_written { render_card }
      expect(keys.count).to eq 1
      expect(keys.first).to include(bike.cache_key_with_version, listing.reload.cache_key_with_version)
      expect(fragments_written { render_card }).to eq([])
      expect(fragments_written { render_card(search_all: true) }.count).to eq 1

      # A price change doesn't touch the bike
      bike_updated_at = bike.reload.updated_at
      listing.update(amount_cents: 7_500)
      expect(bike.reload.updated_at).to eq bike_updated_at
      expect(fragments_written { render_card }.count).to eq 1
    end
  end
end
