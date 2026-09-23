# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::SearchResults::BikeListItem::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:, organization:, search_all:)) }
  let(:organization) { FactoryBot.create(:organization) }
  let(:search_all) { false }
  let(:bike) do
    FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization,
      manufacturer: FactoryBot.create(:manufacturer, name: "Surly"), serial_number: "SUR-77120934")
  end

  it "renders the bike linking to its org page, edged in its status's color" do
    expect(component).to have_css("li.tw\\:border-l-red-600")
    expect(component).to have_link(href: "/bikes/#{bike.id}?organization_id=#{organization.to_param}")
    expect(component).to have_css("strong", text: "Surly")
    expect(component).to have_text("Stolen ·")
    expect(component).to have_text("SUR-77120934")
  end

  context "with search_all" do
    let(:search_all) { true }

    it "says it's registered with the organization" do
      expect(component).to have_text("Registered with #{organization.short_name}")
    end
  end

  context "without an organization" do
    let(:organization) { nil }
    let(:listing) { FactoryBot.create(:marketplace_listing, :for_sale, amount_cents: 420_00) }
    let(:bike) { listing.item.reload }

    it "links to the public bike page, edged in the for-sale color" do
      expect(component).to have_css("li.tw\\:border-l-purple-500")
      expect(component).to have_link(href: bike.html_url)
      expect(component).to have_text("420")
      expect(component).not_to have_text("Registered with")
    end
  end
end
