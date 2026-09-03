# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Tooltip::Component, :js, type: :system do
  let(:preview_url) { "/lookbook/preview/ui/tooltip/variants" }

  def tooltip_position(id)
    page.evaluate_script(<<~JS)
      (() => {
        const style = document.getElementById(#{id.to_json}).style
        return { top: style.top, left: style.left }
      })()
    JS
  end

  # The id of the tooltip the current text selection sits inside, if any
  def selected_tooltip_id
    page.evaluate_script(<<~JS)
      (() => {
        const node = document.getSelection().anchorNode
        return node && node.parentElement.closest("[role='tooltip']")?.id
      })()
    JS
  end

  def tooltip_z_index(id)
    page.evaluate_script("document.getElementById(#{id.to_json}).style.zIndex")
  end

  it "renders accessibly and supports the full hover/focus/click state machine" do
    visit preview_url

    tooltips = all("[role='tooltip']", visible: :all)
    expect(tooltips.size).to be >= 2
    # Capture ids up front; re-reading them off the node handles late in this
    # long test intermittently raises Playwright StaleReferenceError.
    tooltip_ids = tooltips.map { |t| t[:id] }
    expect(tooltip_ids.uniq.size).to eq tooltips.size
    expect_axe_clean

    tooltip = tooltips.first
    trigger = find("[aria-describedby='#{tooltip_ids.first}']")
    expect(trigger.tag_name).to eq "button"
    expect(tooltip.text(:all)).to eq "5–9 mi"
    expect(tooltip).not_to be_visible

    body_tooltip = find(".tooltip-body-imperial", visible: :all).find(:xpath, "ancestor::*[@role='tooltip']", visible: :all)
    expect(body_tooltip).to have_css(".tooltip-body-imperial", text: "5 mi", visible: :all)

    # Hover shows, mouseleave hides
    trigger.hover
    expect(tooltip).to be_visible
    expect(tooltip_position(tooltip_ids.first)).to include("top" => be_present, "left" => be_present)
    find("body").hover
    expect(tooltip).not_to be_visible

    # Focus shows, body click hides
    page.execute_script("arguments[0].focus()", trigger)
    expect(tooltip).to be_visible
    find("body").click
    expect(tooltip).not_to be_visible

    # Hover-only is NOT dismissed by a body click, only by mouseleave
    trigger.hover
    page.execute_script("document.body.click()")
    expect(tooltip).to be_visible
    find("body").hover
    expect(tooltip).not_to be_visible

    # Esc closes the tooltip
    trigger.hover
    expect(tooltip).to be_visible
    page.send_keys(:escape)
    expect(tooltip).not_to be_visible
    find("body").hover

    # Hover-then-focus stays visible until BOTH clear
    trigger.hover
    page.execute_script("arguments[0].focus()", trigger)
    find("body").hover
    expect(tooltip).to be_visible
    find("body").click
    expect(tooltip).not_to be_visible

    # Focus-then-hover is symmetric: stays through mouseleave until the click outside
    page.execute_script("arguments[0].focus()", trigger)
    trigger.hover
    find("body").hover
    expect(tooltip).to be_visible
    find("body").click
    expect(tooltip).not_to be_visible

    # Focus moving to another trigger hides the first
    triggers = tooltip_ids.map { |id| find("[aria-describedby='#{id}']") }
    page.execute_script("arguments[0].focus()", triggers.first)
    expect(tooltips.first).to be_visible
    page.execute_script("arguments[0].focus()", triggers.last)
    expect(tooltips.first).not_to be_visible
    find("body").click

    # Focus leaving with nowhere else to land - the browser window losing focus to
    # another program - is not a dismissal
    page.execute_script("arguments[0].focus()", trigger)
    find("body").hover
    expect(tooltip).to be_visible
    page.execute_script("arguments[0].blur()", trigger)
    expect(tooltip).to be_visible
    find("body").click
    expect(tooltip).not_to be_visible

    # Clicking the trigger persists the tooltip through mouseleave until a body click
    trigger.hover
    trigger.click
    find("body").hover
    expect(tooltip).to be_visible
    find("body").click
    expect(tooltip).not_to be_visible

    # A hovered tooltip is click-through; clicking the trigger open makes its text clickable
    trigger.hover
    expect(tooltip[:class]).to include "tw:pointer-events-none"
    trigger.click
    expect(tooltip[:class]).not_to include "tw:pointer-events-none"

    # Clicking the tooltip text leaves it open, so it can be selected
    tooltip.click
    find("body").hover
    expect(tooltip).to be_visible
    tooltip.double_click
    expect(tooltip).to be_visible
    expect(selected_tooltip_id).to eq tooltip_ids.first
    find("body").click
    expect(tooltip).not_to be_visible

    # Tabbing from the trigger into a link in the popup keeps the tooltip open
    commit_tooltip = find("a[href*='commit']", visible: :all).find(:xpath, "ancestor::*[@role='tooltip']", visible: :all)
    commit_trigger = find("[aria-describedby='#{commit_tooltip[:id]}']")
    commit_trigger.click
    expect(commit_tooltip).to be_visible
    commit_trigger.send_keys(:tab)
    expect(commit_tooltip).to be_visible
    expect(page.evaluate_script("document.activeElement.tagName")).to eq "A"
    find("body").click
    expect(commit_tooltip).not_to be_visible

    # Click layering pushes each clicked tooltip's z-index higher
    tooltip_ids.each { |id| find("[aria-describedby='#{id}']").click }
    z_indexes = tooltip_ids.map { |id| tooltip_z_index(id).to_i }
    expect(z_indexes).to eq z_indexes.sort
    expect(z_indexes.last).to be > z_indexes.first
  end

  it "is accessible in dark mode" do
    visit "#{preview_url}?_display=#{CGI.escape({theme: "dark"}.to_json)}"

    expect(page).to have_css("[role='tooltip']", visible: :all)
    expect_axe_clean
  end
end
