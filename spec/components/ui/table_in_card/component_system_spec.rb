# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableInCard::Component, :js, type: :system do
  it "checks the rows between a click and a shift-click, to the shift-clicked one's state, and toggles all" do
    visit("/rails/view_components/ui/table_in_card/component/selection")
    boxes = (1..5).map { find_field("cryptids[#{it}]") }

    boxes[1].click
    boxes[3].click(:shift)
    expect(boxes.map(&:checked?)).to eq [false, true, true, true, false]

    boxes[3].click
    boxes[1].click(:shift)
    expect(boxes.map(&:checked?)).to all(be false)

    click_button(title: "Toggle all checked")
    expect(boxes.map(&:checked?)).to all(be true)
    expect_axe_clean
  end
end
