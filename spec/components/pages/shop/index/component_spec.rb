# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Shop::Index::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "links each product to its Shopify page in a new tab, with no cart" do
    {"the-caped-registrant-cap" => "The Caped Registrant cap",
     "bike-index-info-card-sticker" => "Bike Index registration stickers"}.each do |handle, name|
      expect(component).to have_css("a[href='https://bikeindex.myshopify.com/products/#{handle}'][target=_blank][rel=noopener]", text: "View")
      expect(component).to have_css("a[aria-label='View #{name} on the Bike Index shop (opens in a new tab)']")
    end
    expect(component).to have_no_button
    expect(component).to have_text("$20.00").and have_text("$7.99")
  end

  it "scrolls the hero's button to the first product and offers bulk orders by email" do
    expect(component).to have_link("Shop the gear", href: "#caped-registrant-cap")
    expect(component).to have_css("section#caped-registrant-cap")
    expect(component).to have_css("section#registration-stickers")
    expect(component).to have_link("Contact us", href: "mailto:gavin@bikeindex.org?subject=Bulk%20sticker%20order")
  end
end
