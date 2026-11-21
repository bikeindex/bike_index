# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bike Book schema viewer", :js, type: :system do
  def toggle(path) = find("details[data-schema-path='#{path}'] > summary").click

  it "keeps what's opened and what's ordered by count in the URL, while it shows" do
    visit "/bikebook_schema"
    expect(page).to have_no_css("details[open]")

    toggle("type")
    expect(page).to have_current_path("/bikebook_schema?open=type")

    find("details[data-schema-path='type'] label", text: "by count").click
    expect(page).to have_current_path("/bikebook_schema?open=type&by_count=type")

    toggle("frame")
    toggle("frame.mounts")
    expect(page).to have_current_path("/bikebook_schema?open=type,frame,frame.mounts&by_count=type")

    # closed around it, frame.mounts no longer shows
    toggle("frame")
    expect(page).to have_current_path("/bikebook_schema?open=type&by_count=type")

    toggle("type")
    expect(page).to have_current_path("/bikebook_schema")
  end
end
