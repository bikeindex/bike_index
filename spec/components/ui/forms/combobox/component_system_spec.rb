# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Combobox::Component, :js, type: :system do
  it "opens, filters, selects, and closes" do
    visit "/rails/view_components/ui/forms/combobox/component/default"

    # `aria-expanded` is set by the combobox Stimulus controller on connect, not
    # in the server-rendered HTML -- wait out the first JS connect on slow CI.
    expect(page).to have_css('[aria-expanded="false"]', wait: 10)
    expect_axe_clean

    # Opens the listbox on click
    find_field("Cycle type").click

    expect(page).to have_css('[aria-expanded="true"]')
    expect(page).to have_css('[role="option"]', count: CycleType.slugs.count)
    expect_axe_clean

    # Filters the options as you type
    fill_in "Cycle type", with: "cargo"

    expect(page).to have_css('[role="option"]', text: "Cargo Bike (front storage)")
    expect(page).to have_css('[role="option"]', text: "Cargo Tricycle (trike with rear storage)")
    expect(page).not_to have_css('[role="option"]', text: "Unicycle")

    # Selecting an option closes the listbox and fills the visible input
    # and the hidden field that carries the form value
    find('[role="option"]', text: "Cargo Bike (front storage)").click

    expect(page).to have_css('[aria-expanded="false"]')
    expect(find_field("Cycle type").value).to eq "Cargo Bike (front storage)"
    expect(find("input[name='cycle_type']", visible: :hidden).value).to eq "Cargo Bike (front storage)"

    # Reopen, then close with the Escape key
    find_field("Cycle type").click

    expect(page).to have_css('[aria-expanded="true"]')

    send_keys(:escape)

    expect(page).to have_css('[aria-expanded="false"]')
  end

  context "with rich_display" do
    let(:overlay) { "[data-ui--forms--combobox-display-target='overlay']" }

    it "mirrors the selected option's two-tone content onto the closed input" do
      visit "/rails/view_components/ui/forms/combobox/component/rich_display"

      # Nothing selected yet, so there is no rich content to mirror
      expect(page).to have_css('[aria-expanded="false"]', wait: 10)
      expect(page).to have_no_css(overlay)

      find_field("Cycle type").click
      find('[role="option"]', text: "Cargo Bike (front storage)").click

      expect(page).to have_css(overlay, text: "Cargo Bike (front storage)")
      expect(page).to have_css("#{overlay} span", text: "(front storage)")

      # Clicking in to filter again hands the plain input back to the user
      find_field("Cycle type").click

      expect(page).to have_no_css(overlay)
    end
  end
end
