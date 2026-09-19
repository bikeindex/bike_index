# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Table::Component, :js, type: :system do
  it "sortable_with_cache is axe clean" do
    visit("/rails/view_components/ui/table/component/sortable_with_cache")

    expect(page).to have_css("table")
    expect_axe_clean
  end

  it "closes the footer row's outer edges" do
    visit("/rails/view_components/ui/table/component/with_footer")

    expect(page).to have_css("tfoot td", text: "Total")
    edges = page.evaluate_script(<<~JS)
      (() => {
        const cells = document.querySelectorAll("tfoot td")
        const first = getComputedStyle(cells[0])
        const last = getComputedStyle(cells[cells.length - 1])
        return [first.borderLeftWidth, first.borderBottomLeftRadius, last.borderRightWidth, last.borderBottomRightRadius]
      })()
    JS
    expect(edges).to eq(["1px", "4px", "1px", "4px"])
  end
end
