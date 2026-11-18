# frozen_string_literal: true

require "rails_helper"

RSpec.describe "shop", :js, type: :system do
  let(:products) do
    {"The Caped Registrant cap" => "the-caped-registrant-cap", "Pink or Black Bike Index cap" => "bike-index-cycling-cap",
     "Bike Index registration stickers" => "bike-index-info-card-sticker"}
  end

  def expect_eventually(message, &block)
    page.document.synchronize { raise Capybara::ExpectationNotMet, message unless block.call }
  end

  def first_product_top = page.evaluate_script("document.getElementById('caped-registrant-cap').getBoundingClientRect().top")

  def horizontal_scroll? = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

  def corner(element) = element.evaluate_script("(({ x, y }) => [Math.round(x), Math.round(y)])(this.getBoundingClientRect())")

  it "scrolls to the products, links each to Shopify, and keeps its layout from phone to desktop" do
    resize_window(width: 1280, height: 900)
    visit "/shop"
    expect(page).to have_css("h1", text: "Gear that helps get bikes home.", wait: 10)
    wait_for_stimulus("shop--index")
    expect_axe_clean

    # The controller scrolls rather than jumping, which is why the URL doesn't gain the anchor
    click_link "Shop the gear"
    expect_eventually("first product at #{first_product_top}px") { first_product_top.between?(0, 40) }
    expect(page.evaluate_script("window.location.hash")).to eq ""

    # Each View is a plain link to its product on the store, in a new tab and with no cart
    products.each_value do |handle|
      link = find_link("View", href: "https://bikeindex.myshopify.com/products/#{handle}")
      expect(link[:target]).to eq "_blank"
      expect(link[:rel]).to eq "noopener"
    end
    expect(page).to have_no_button("Add to cart")
    expect(page).to have_link("Contact us", href: "mailto:support@bikeindex.org")

    # The pink cap's image is on the right wherever the row has two columns, including the width
    # between where it wraps and the md breakpoint
    image = find("img[alt^='Illustration of the pink ripstop']")
    heading = find("h2", text: "Pink or Black Bike Index cap")
    [1280, 740].each do |width|
      resize_window(width:, height: 900)
      expect_eventually("pink cap image not right of its heading at #{width}px") { corner(image).first > corner(heading).first }
    end

    # Stacked, every image sits above its text, and nothing spills sideways at the narrowest phones
    [700, 390, 320].each do |width|
      resize_window(width:, height: 900)
      expect_eventually("pink cap image not above its heading at #{width}px") { corner(image).last < corner(heading).last }
      expect_eventually("horizontal scroll at #{width}px") { !horizontal_scroll? }
    end
    expect_axe_clean
  end
end
