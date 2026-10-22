# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableColumnSettings::Component, :js, type: :system do
  def column_order = all("thead th.hideableColumn").map { it[:class][/\w+_cell/] }

  it "moves a column dragged by its handle, and keeps the order after a reload" do
    visit "/rails/view_components/ui/table_column_settings/component/default"

    expect(column_order).to eq %w[color_cell size_cell]
    expect_axe_clean

    # Only the handle drags - the header around it doesn't
    find("th.size_cell").drag_to(find("th.color_cell"))
    expect(column_order).to eq %w[color_cell size_cell]

    find("th.size_cell [data-ui--table-column-order-target='handle']").drag_to(find("th.color_cell"))
    expect(page).to have_css("thead th.size_cell + th.color_cell")
    expect(page).to have_css("tbody tr:first-child td.size_cell + td.color_cell")

    # A reload, to the order the drag stored
    visit page.current_url
    expect(page).to have_css("thead th.size_cell + th.color_cell")
  end
end
