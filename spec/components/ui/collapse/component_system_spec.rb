# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ui--collapse controller", :js, type: :system do
  let(:preview_path) { "/rails/view_components/ui/collapse/component/with_url_param" }

  it "toggles, clips while opening, persists open state to the URL or localStorage, and restores it on load" do
    visit preview_path

    # Starts collapsed (tw:hidden), so the body isn't visible and the param is absent.
    expect(page).to have_no_content("Persisted panel body")

    # Registered after Stimulus's, so the frame it samples is one the collapse has
    # already started: the panel pinned to 0 height with the transition running.
    page.execute_script(<<~JS)
      document.querySelector("[data-ui--collapse-target='trigger']").addEventListener("click", () => {
        requestAnimationFrame(() => {
          const box = document.getElementById("panel_checkbox").getBoundingClientRect()
          const hit = document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2)
          document.body.dataset.hitWhileOpening = hit.id || hit.tagName
        })
      })
    JS

    click_button("Toggle details")

    # The checkbox sits at its full-open offset from the first frame, so unclipped it would
    # be what's hit there - covering, and taking the clicks aimed at, what slides past below.
    expect(page).to have_css("body[data-hit-while-opening='below']")
    # Reachable again once it settles
    check "panel_checkbox"
    expect(page).to have_checked_field("panel_checkbox")

    # ui--collapse#show reveals the body, writes ?details=1 via history.replaceState,
    # and flips the trigger's aria-expanded and data-active.
    expect(page).to have_content("Persisted panel body")
    expect(page).to have_current_path(/details=1/, url: true)
    expect(page).to have_css("[role='button'][aria-expanded='true'][data-active='true']", text: "Toggle details")
    # Rotated, which is what spins a trigger's icon while its panel is open
    expect(page).to have_css("[data-ui--collapse-target='chevron'].tw\\:rotate-90")

    expect_axe_clean

    # Reloading with the param restores the open state (and the trigger's flags) without a click.
    visit "#{preview_path}?details=1"
    expect(page).to have_content("Persisted panel body")
    expect(page).to have_css("[role='button'][aria-expanded='true'][data-active='true']", text: "Toggle details")

    # Collapsing writes 0 rather than dropping the param, so the state is always explicit.
    click_button("Toggle details")
    expect(page).to have_no_content("Persisted panel body")
    expect(page).to have_current_path(/details=0/, url: true)
    expect(page).to have_css("[role='button'][aria-expanded='false'][data-active='false']", text: "Toggle details")

    # And it's restored collapsed, rather than the param's presence alone opening it
    visit "#{preview_path}?details=0"
    expect(page).to have_no_content("Persisted panel body")
    expect(page).to have_css("[role='button'][aria-expanded='false'][data-active='false']", text: "Toggle details")

    # The storage-key panel keeps the same state in localStorage, so the URL stays clean
    visit "/rails/view_components/ui/collapse/component/with_storage_key"
    expect(page).to have_no_content("Stored panel body")

    click_button("Toggle stored panel")
    expect(page).to have_content("Stored panel body")
    expect(page).not_to have_current_path(/\?/, url: true)

    visit "/rails/view_components/ui/collapse/component/with_storage_key"
    expect(page).to have_content("Stored panel body")
    expect(page).to have_css("[role='button'][aria-expanded='true']", text: "Toggle stored panel")

    click_button("Toggle stored panel")
    expect(page).to have_no_content("Stored panel body")
    visit "/rails/view_components/ui/collapse/component/with_storage_key"
    expect(page).to have_no_content("Stored panel body")
  end

  it "selects the trigger's label on a drag, and toggles on a click or a key" do
    visit "/rails/view_components/ui/collapse/component/selectable"
    wait_for_stimulus("ui--collapse")
    expect_axe_clean

    label = find("span", exact_text: "Selectable label")
    drag_select(label, past: -2)
    expect(page.evaluate_script("window.getSelection().toString()")).to start_with("Selectable lab")
    expect(page).to have_css("[role='button'][aria-expanded='false']")

    # A double click selects a word, and leaves the panel as it found it
    label.double_click
    expect(page.evaluate_script("window.getSelection().toString()")).to eq "Selectable"
    expect(page).to have_css("[role='button'][aria-expanded='false']")
    expect(page).to have_no_content("Selectable panel body")

    # A click on the label while it's still selected toggles as usual
    label.click
    expect(page).to have_content("Selectable panel body")
    expect(page).to have_css("[role='button'][aria-expanded='true'][data-active='true']")
    expect(page.evaluate_script("getComputedStyle(document.querySelector('[role=button]')).fontWeight")).to eq "700"

    trigger = find("[data-ui--collapse-target='trigger']")
    trigger.send_keys(:enter)
    expect(page).to have_no_content("Selectable panel body")
    trigger.send_keys(:space)
    expect(page).to have_content("Selectable panel body")
  end
end
