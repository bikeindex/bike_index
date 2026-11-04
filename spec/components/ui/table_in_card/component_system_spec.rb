# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableInCard::Component, :js, type: :system do
  it "checks the rows between a click and a shift-click, to the shift-clicked one's state, and toggles all" do
    visit("/lookbook/preview/ui/table_in_card/variants")
    wait_for_stimulus("table-multi-checkbox")
    boxes = (1..6).map { find_field("cryptids[#{it}]") }

    boxes[1].click
    boxes[3].click(:shift)
    expect(boxes.map(&:checked?)).to eq [false, true, true, true, false, false]

    boxes[3].click
    boxes[1].click(:shift)
    expect(boxes.map(&:checked?)).to all(be false)

    click_button(title: "Toggle all checked")
    expect(boxes.map(&:checked?)).to all(be true)
    expect_axe_clean
  end
end
