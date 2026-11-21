# frozen_string_literal: true

require "rails_helper"

RSpec.describe "shop", :js, type: :system do
  def first_product_top = page.evaluate_script("document.getElementById('caped-registrant-cap').getBoundingClientRect().top")

  def horizontal_scroll? = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth")

  def corner(element) = element.evaluate_script("(({ x, y }) => [Math.round(x), Math.round(y)])(this.getBoundingClientRect())")

  it "scrolls to the products and keeps its layout from phone to desktop" do
    resize_window(width: 1280, height: 900)
    visit "/shop"
    expect(page).to have_css("h1", text: "Gear that helps get bikes home.", wait: 10)
    wait_for_stimulus("scroll-to-hash")
    expect_axe_clean

    # The controller scrolls rather than jumping, which is why the URL doesn't gain the anchor
    click_link "Shop the gear"
    wait_for { first_product_top.between?(0, 40) }
    expect(page.evaluate_script("window.location.hash")).to eq ""

    # The pink cap's image is on the right wherever the row has two columns, down to where it wraps
    image = find("img[alt^='Illustration of the pink ripstop']")
    heading = find("h2", text: "Pink or Black Bike Index cap")
    [1280, 760].each do |width|
      resize_window(width:, height: 900)
      wait_for { corner(image).first > corner(heading).first }
    end

    # Stacked, every image sits above its text, and nothing spills sideways at the narrowest phones
    [700, 390, 320].each do |width|
      resize_window(width:, height: 900)
      wait_for { corner(image).last < corner(heading).last }
      wait_for { !horizontal_scroll? }
    end
    expect_axe_clean
  end
end
