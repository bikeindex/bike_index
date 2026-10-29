# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableColumnSettings::Component, :js, type: :system do
  def column_order = all("thead th.hideableColumn").map { it[:class][/\w+_cell/] }

  it "moves a column dragged by its handle or by its arrow keys, keeps the order after a reload, and returns it to default" do
    visit "/rails/view_components/ui/table_column_settings/component/default"

    expect(column_order).to eq %w[color_cell size_cell]
    click_button "Column settings"
    expect(page).to have_button("all")
    expect(page).to have_no_button("return to default order")
    expect_axe_clean

    # Only the handle drags - the header around it doesn't
    find("th.size_cell").drag_to(find("th.color_cell"))
    expect(column_order).to eq %w[color_cell size_cell]

    find("th.size_cell [data-ui--table-column-order-target='handle']").drag_to(find("th.color_cell"))
    expect(page).to have_css("thead th.size_cell + th.color_cell")
    expect(page).to have_css("tbody tr:first-child td.size_cell + td.color_cell")
    expect(page).to have_button("return to default order")

    # Past the unchecked Notes column, which isn't counted. Back in the default order, the reset goes
    find("[aria-label='Move Size']").send_keys(:right)
    expect(page).to have_css("thead th.color_cell + th.size_cell")
    expect(page).to have_css("#drag-handle-status", text: "Position 2 of 2", visible: :all)
    expect(page).to have_no_button("return to default order")
    send_keys(:left)
    expect(page).to have_css("thead th.size_cell + th.color_cell")
    expect(page).to have_css("#drag-handle-status", text: "Position 1 of 2", visible: :all)
    expect(page).to have_button("return to default order")

    # A reload, to the order the drag stored
    visit page.current_url
    expect(page).to have_css("thead th.size_cell + th.color_cell")

    click_button "return to default order"
    expect(page).to have_css("thead th.color_cell + th.size_cell")
    expect(page).to have_no_button("return to default order")
    visit page.current_url
    expect(page).to have_css("thead th.color_cell + th.size_cell")
  end
end
