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

  # Where the card's settings and the line under its table start and end
  let(:edges) do
    <<~JS
      (() => {
        const row = document.querySelector("[data-table-bleed]")
        const span = (element) => [element.getBoundingClientRect().left, element.getBoundingClientRect().right]
        const line = [...row.querySelectorAll("*")].find((element) => element.querySelector(":scope > * > * > table") && getComputedStyle(element).borderBottomWidth === "1px")
        return {settings: span(row.querySelector("[data-ui--collapse-target='content']")), line: line && span(line)}
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

    resize_window(width: 500, height: 800)
    table_width = page.evaluate_script(%(document.querySelector("[data-table-bleed] table").getBoundingClientRect().width)).ceil

    # Wider than the table once it bleeds, and narrower while it's inset: what would flip back and forth
    resize_window(width: table_width + 20, height: 800)
    expect(page).to have_css("[data-table-bleed='true']", count: 2)
    expect(page.evaluate_script(bleed_samples)).to eq("samples" => ["true"], "left" => 0)

    click_button("Column settings", match: :first)
    settle_animations(find("[data-ui--collapse-target='content']", match: :first))
    expect(page.evaluate_script(edges)).to eq("settings" => [0, table_width + 20], "line" => [0, table_width + 20])

    resize_window(width: table_width + 60, height: 800)
    expect(page).to have_css("[data-table-bleed='false']", minimum: 1)
    result = page.evaluate_script(bleed_samples)
    expect(result["samples"]).to eq ["false"]
    expect(result["left"]).to be > 0
  end

  it "shadows the frozen column in dark mode, keeps region and header text quieter than cells, and a shadow with its own color keeps it" do
    resize_window(width: 500, height: 800)
    visit("/rails/view_components/ui/table_in_card/component/default?lookbook%5Bdisplay%5D%5Btheme%5D=dark")
    expect(page).to have_css("[data-controller~='ui--table-overflow'][data-overflowing]")
    expect(computed_ring(first("tbody td"))).to include("rgba(0, 0, 0, 0.5) 2px 0px 6px")
    colors = page.evaluate_script(%(["tbody td", "tbody small", "thead th"].map((selector) => getComputedStyle(document.querySelector(selector)).color)))
    expect(colors.second).to eq colors.third
    expect(colors.first).not_to eq colors.second

    visit("/rails/view_components/ui/card/component/with_black_shadow?lookbook%5Bdisplay%5D%5Btheme%5D=dark")
    card_shadow = page.evaluate_script(%([...document.querySelectorAll("div")].map((div) => getComputedStyle(div).boxShadow).find((shadow) => shadow.includes("4px 4px"))))
    expect(card_shadow).to be_present
    expect(card_shadow).not_to include("rgba(0, 0, 0, 0.5)")
    expect_axe_clean
  end
end
