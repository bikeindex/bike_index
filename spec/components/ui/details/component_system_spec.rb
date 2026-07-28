# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ui--details controller", :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/details/component/with_animation" }

  it "toggles the native <details> open/closed and animates the content" do
    visit preview_path

    # Starts closed, so the body isn't visible.
    expect(page).to have_no_content("Native <details> body")
    expect(page).to have_no_css("details[open]")

    find("summary").click

    # ui--details#toggle opens the native element and animates the content in.
    expect(page).to have_content("Native <details> body")
    expect(page).to have_css("details[open]")

    expect_axe_clean

    find("summary").click

    # Closing animates out, then clears the open attribute once the animation ends.
    expect(page).to have_no_content("Native <details> body")
    expect(page).to have_no_css("details[open]")
  end
end
