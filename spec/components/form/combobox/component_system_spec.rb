# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::Combobox::Component, :js, type: :system do
  it "opens, filters, selects, and closes" do
    visit "/rails/view_components/form/combobox/component/default"

    # `aria-expanded` is set by the combobox Stimulus controller on connect, not
    # in the server-rendered HTML -- wait out the first JS connect on slow CI.
    expect(page).to have_css('[aria-expanded="false"]', wait: 10)
    expect_axe_clean

    # Opens the listbox on click
    find_field("Manufacturer").click

    expect(page).to have_css('[aria-expanded="true"]')
    expect(page).to have_css('[role="option"]', count: 6)
    expect_axe_clean

    # Filters the options as you type
    fill_in "Manufacturer", with: "an"

    expect(page).to have_css('[role="option"]', text: "Giant")
    expect(page).to have_css('[role="option"]', text: "Cannondale")
    expect(page).not_to have_css('[role="option"]', text: "Trek")

    # Selecting an option closes the listbox and fills the visible input
    # and the hidden field that carries the form value
    find('[role="option"]', text: "Cannondale").click

    expect(page).to have_css('[aria-expanded="false"]')
    expect(find_field("Manufacturer").value).to eq "Cannondale"
    expect(find("input[name='manufacturer']", visible: :hidden).value).to eq "Cannondale"

    # Reopen, then close with the Escape key
    find_field("Manufacturer").click

    expect(page).to have_css('[aria-expanded="true"]')

    send_keys(:escape)

    expect(page).to have_css('[aria-expanded="false"]')
  end
end
