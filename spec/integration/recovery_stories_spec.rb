# frozen_string_literal: true

require "rails_helper"

RSpec.describe "recovery stories", :js, type: :system do
  before do
    FactoryBot.create(:stripe_price_basic)
    FactoryBot.create(:stripe_price_plus)
    FactoryBot.create(:stripe_price_patron)
    FactoryBot.create(:recovery_display, quote: "Newest story", recovered_at: 1.day.ago)
    FactoryBot.create(:recovery_display, quote: "Middle story", recovered_at: 2.days.ago, link: "/about")
    FactoryBot.create(:recovery_display, quote: "Oldest story", recovered_at: 3.days.ago)
  end

  def stories = page.all("blockquote").map(&:text)

  it "loads more in place, recording it in the URL, and reaches every other page" do
    visit "/recovery_stories?per_page=1"
    expect(page).to have_css("blockquote", text: "Newest story", wait: 10)
    expect(page).to have_no_link("Newer stories")

    click_link "Load more stories"
    expect(page).to have_css("blockquote", text: "Middle story")
    expect(page).to have_current_path("/recovery_stories?page=2&per_page=1")

    click_link "Load more stories"
    expect(page).to have_css("blockquote", text: "Oldest story")
    expect(page).to have_current_path("/recovery_stories?page=3&per_page=1")
    expect(stories).to eq(["Newest story", "Middle story", "Oldest story"])
    expect(page).to have_no_link("Load more stories")
    expect_axe_clean

    # Reloading lands on the page the URL recorded, with a way back to the newer ones
    visit page.current_url
    expect(page).to have_css("blockquote", count: 1, text: "Oldest story")

    click_link "Newer stories"
    expect(page).to have_current_path("/recovery_stories?page=2&per_page=1")
    expect(stories).to eq(["Middle story"])

    within_window(window_opened_by { click_link "/about" }) do
      expect(page).to have_current_path("/about")
    end
    expect(stories).to eq(["Middle story"])
    expect(page).to have_no_text("Content missing")
  end
end
