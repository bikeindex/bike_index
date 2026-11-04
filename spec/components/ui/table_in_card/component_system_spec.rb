# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableInCard::Component, :js, type: :system do
  # Every animation frame's data-table-bleed, and where the card's table starts
  let(:bleed_samples) do
    <<~JS
      (async () => {
        const row = document.querySelector("[data-table-bleed]")
        const samples = []
        for (let frame = 0; frame < 20; frame++) {
          samples.push(row.dataset.tableBleed)
          await new Promise(requestAnimationFrame)
        }
        return {samples: [...new Set(samples)], left: row.querySelector("table").getBoundingClientRect().left}
      })()
    JS
  end

  it "selects a shift-clicked range, toggles all, and bleeds once the table is wider than the card, without flipping back" do
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

    original_size = page.current_window.size
    page.current_window.resize_to(500, 800)
    table_width = page.evaluate_script(%(document.querySelector("[data-table-bleed] table").getBoundingClientRect().width)).ceil

    # Wider than the table once it bleeds, and narrower while it's inset: what would flip back and forth
    page.current_window.resize_to(table_width + 20, 800)
    expect(page).to have_css("[data-table-bleed='true']", count: 2)
    expect(page.evaluate_script(bleed_samples)).to eq("samples" => ["true"], "left" => 0)

    page.current_window.resize_to(table_width + 60, 800)
    expect(page).to have_css("[data-table-bleed='false']", minimum: 1)
    result = page.evaluate_script(bleed_samples)
    expect(result["samples"]).to eq ["false"]
    expect(result["left"]).to be > 0
    page.current_window.resize_to(*original_size)
  end
end
