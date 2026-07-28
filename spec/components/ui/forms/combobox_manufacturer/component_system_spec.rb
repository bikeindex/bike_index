# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::ComboboxManufacturer::Component, :js, type: :system do
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly", frame_maker: true) }
  let(:hidden_field) { find("input[name='manufacturer_id']", visible: :hidden) }
  # Matcher results are cached in redis for 10 minutes, which outlives the example
  before { Autocomplete::Loader.clear_redis && Autocomplete::Loader.load_all(%w[Manufacturer]) }

  it "selects an indexed manufacturer, and enters an unindexed one as free text" do
    visit "/rails/view_components/ui/forms/combobox_manufacturer/component/default"

    # `aria-expanded` is set by the combobox Stimulus controller on connect, not
    # in the server-rendered HTML -- wait out the first JS connect on slow CI.
    expect(page).to have_css('[aria-expanded="false"]', wait: 10)

    type_into(find_field("Manufacturer"), "sur")

    expect(page).to have_css('[role="option"]', text: "Surly")
    expect(page).to have_css('[role="option"]', text: "Unknown manufacturer")
    expect(page).to_not have_css('[role="option"]', text: "Other")

    # The typed text autocompletes to the manufacturer, which is selected on close
    send_keys(:enter)

    expect(page).to have_css('[aria-expanded="false"]')
    expect(find_field("Manufacturer").value).to eq "Surly"
    expect(hidden_field.value).to eq manufacturer.id.to_s

    # An unindexed manufacturer is entered through the unknown option
    type_into(find_field("Manufacturer"), "Bikes by Seth")
    click_combobox_option("Unknown manufacturer Bikes by Seth")

    expect(page).to have_css('[aria-expanded="false"]')
    expect(find_field("Manufacturer").value).to eq "Bikes by Seth"
    expect(hidden_field.value).to eq "Bikes by Seth"

    # With no_manufacturer_other, free text isn't offered or kept. This preview
    # renders the bare component, which has no label of its own
    visit "/rails/view_components/ui/forms/combobox_manufacturer/component/no_manufacturer_other"

    expect(page).to have_css('[aria-expanded="false"]', wait: 10)

    type_into(find("input[role='combobox']"), "Bikes by Seth")

    expect(page).to_not have_css('[role="option"]')

    send_keys(:enter)

    expect(hidden_field.value).to be_blank
  end
end
