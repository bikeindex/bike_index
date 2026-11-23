# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bike Book schema viewer", :js, type: :system do
  before { serve_bikebook_catalog }

  def toggle(path) = find("details[data-schema-path='#{path}'] > summary").click

  it "keeps what's opened and what's ordered by count in the URL, while it shows, and renders a model searched for" do
    visit "/bikebook_schemas"
    expect(page).to have_no_css("details[open]")

    toggle("type")
    expect(page).to have_current_path("/bikebook_schemas?open=type")

    find("details[data-schema-path='type'] label", text: "by count").click
    expect(page).to have_current_path("/bikebook_schemas?open=type&by_count=type")

    toggle("frame")
    toggle("frame.mounts")
    expect(page).to have_current_path("/bikebook_schemas?open=type,frame,frame.mounts&by_count=type")

    # closed around it, frame.mounts no longer shows
    toggle("frame")
    expect(page).to have_current_path("/bikebook_schemas?open=type&by_count=type")

    toggle("type")
    expect(page).to have_current_path("/bikebook_schemas")

    {"segway/2025/gt3-pro" => %w[Segway GT3\ Pro], "specialized/2025/haul-st" => %w[Specialized Haul\ ST]}.each do |path, (manufacturer, model)|
      WebMock.stub_request(:get, "#{Integrations::Bikebook::RepositoryRecord::URL}vehicle_models/#{path}.json")
        .to_return(body: {id: "m/#{path}", manufacturer:, model:}.to_json)
    end
    type_into(find_field("View a model's or e-vehicle classification's file", disabled: false, wait: 10), "gt3")
    retry_on_detach { find("[role='option']", text: "Segway GT3 Pro").click }
    expect(page).to have_current_path("/bikebook_schemas/m/segway/2025/gt3-pro")
    expect(page).to have_css("pre", text: %("manufacturer": "Segway",)).and have_no_css("[data-schema-path]")
    field = find_field("View a model's or e-vehicle classification's file", disabled: false, wait: 10)
    expect(field.value).to eq "Segway GT3 Pro"
    # a click selects the pick, to type another over
    field.click
    field.send_keys("haul")
    retry_on_detach { find("[role='option']", text: "Specialized Haul ST").click }
    expect(page).to have_current_path("/bikebook_schemas/m/specialized/2025/haul-st")
    expect(page).to have_css("pre", text: %("manufacturer": "Specialized",))

    # Escape closes a search without picking from it, back to the pick
    field = find_field("View a model's or e-vehicle classification's file", disabled: false, wait: 10)
    field.click
    field.send_keys("gt3")
    expect(page).to have_css("[role='option']", text: "Segway GT3 Pro")
    field.send_keys(:escape)
    expect(page).to have_no_css("[role='option']")
    expect(field.value).to eq "Specialized Haul ST"
    expect(page).to have_current_path("/bikebook_schemas/m/specialized/2025/haul-st")

    # deleting the pick goes back to the document's fields, as its clear does
    find("h1", text: "Bike Book schemas").click
    field.click
    field.send_keys(:backspace)
    expect(page).to have_current_path("/bikebook_schemas?document=vehicle_model")
    expect(page).to have_css("[data-schema-path='type']").and have_no_css("pre")
  end
end
