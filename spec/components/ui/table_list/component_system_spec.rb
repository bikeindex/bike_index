# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableList::Component, :js, type: :system do
  it "keeps labels on whole words and values inside the panel" do
    visit "/rails/view_components/ui/table_list/component/narrow"

    expect(page).to have_css("th", text: "Serial number", wait: 10)
    table_right, panel_right, label_width = page.evaluate_script(<<~JS)
      (() => {
        const table = document.querySelector("table")
        return [table.getBoundingClientRect().right,
          table.parentElement.getBoundingClientRect().right,
          table.querySelector("th").getBoundingClientRect().width]
      })()
    JS

    expect(table_right).to be <= panel_right
    expect(label_width).to be > 40
  end
end
