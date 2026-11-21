# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bike Book schema viewer", :js, type: :system do
  it "keeps what's opened, and what's ordered by count, in the URL" do
    visit "/bikebook/schema_viewer"

    find("details[data-schema-path='type'] > summary").click
    expect(page).to have_current_path("/bikebook/schema_viewer?open=type")

    find("details[data-schema-path='type'] label", text: "by count").click
    expect(page).to have_current_path("/bikebook/schema_viewer?open=type&by_count=type")

    find("details[data-schema-path='frame.mounts'] > summary").click
    expect(page).to have_current_path("/bikebook/schema_viewer?open=type,frame.mounts&by_count=type")

    find("details[data-schema-path='type'] > summary").click
    expect(page).to have_current_path("/bikebook/schema_viewer?open=frame.mounts")
  end
end
