# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Table::Base::Component, :js, type: :system do
  it "sortable_with_cache and row_headers are axe clean" do
    visit("/rails/view_components/ui/table/base/component/sortable_with_cache")

    expect(page).to have_css("table")
    expect_axe_clean

    visit("/rails/view_components/ui/table/base/component/row_headers")
    expect(page).to have_css("th[scope='row']", text: "Sightings")
    expect_axe_clean
  end

  it "closes the footer row's outer edges" do
    visit("/rails/view_components/ui/table/base/component/with_footer")

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

    visit("/rails/view_components/ui/table/base/component/with_footer?lookbook%5Bdisplay%5D%5Btheme%5D=dark")
    expect(page).to have_css("tfoot td", text: "Total")
    colors = page.evaluate_script(<<~JS)
      (() => {
        const [row, stripedRow] = document.querySelectorAll("tbody tr")
        const cell = getComputedStyle(row.querySelector("td"))
        const footer = getComputedStyle(document.querySelector("tfoot td"))
        return {line: cell.borderBottomColor, side: cell.borderLeftColor, stripe: getComputedStyle(stripedRow).backgroundColor,
          footerBottom: footer.borderBottomColor, footerSide: footer.borderLeftColor}
      })()
    JS
    expect(colors["line"]).to eq colors["stripe"]
    expect(colors["side"]).not_to eq colors["line"]
    expect(colors["footerBottom"]).to eq colors["footerSide"]
  end
end
