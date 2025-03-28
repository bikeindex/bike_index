# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Form::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/form/component/default" }

  before do
    # Stub the API_URL to use the production autocomplete url, for more accurate testing
    # Fails because of CORS policy currently, will be fixed after deploy update
    # stub_const("Search::EverythingCombobox::Component::API_URL", "https://bikeindex.org/api/autocomplete")
  end
  let(:default_params) do
    {
      distance: ["100"],
      location: [""],
      "query_item[]" => [],
      stolenness: ["stolen", "stolen"],
      # stolenness: "stolen", # TODO: above should be this
      serial: [""]
    }
  end

  def page_query_params(url)
    uri = URI.parse(url)
    CGI.parse(uri.query || "")
  end

  # TODO:
  # - system specs for everything combobox
  #   - enter twice to submit
  #   - pagination
  # - system specs for submitting
  #   - updates the URL


  it "adds an item when selected" do
    visit(preview_path)

    expect(find('#query_items', visible: false).value).to be_blank
    find('.select2-container').click

    expect(page).to have_content("Bikes that are Black", wait: 5)
    find('li', text: 'Bikes that are Black').click

    expect(page).to have_css('.select2-selection__rendered', text: 'Black')

    # TODO: Once using production, actually test the values are correct
    # expect(find('#query_items', visible: false).value).to eq(["c_1"])
    new_values = find('#query_items', visible: false).value
    expect(new_values.count).to eq 1
    expect(new_values.first).to match('c_')
  end

  it "submits when enter is pressed twice" do
    visit(preview_path)

    expect(find('#query_items', visible: false).value).to be_blank
    find('.select2-container').click
    # Wait for select2 to load
    expect(page).to have_content("Bikes that are Black", wait: 5)

    page.send_keys :arrow_down
    page.send_keys :arrow_down
    page.send_keys :arrow_down

    page.send_keys :return

    # TODO: Once using production, actually test the values are correct
    # expect(find('#query_items', visible: false).value).to eq(["c_5"])
    new_values = find('#query_items', visible: false).value
    expect(new_values.count).to eq 1

    page.send_keys(:return)
    expect(page).to have_current_path(/\?/, wait: 5)



    expect(page_query_params(current_url))
      .to match_hash_indifferently(default_params.merge("query_items[]" => new_values))
  end

  it "scrolls through paginated options" do
  end
end
