# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Tooltip::Component, :js, type: :system do
  let(:preview_url) { "/rails/view_components/ui/tooltip/component/multiple" }

  def tooltip_position(id)
    page.evaluate_script(<<~JS)
      (() => {
        const style = document.getElementById(#{id.to_json}).style
        return { top: style.top, left: style.left }
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
    expect(tooltips.map { |t| t[:id] }.uniq.size).to eq tooltips.size
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

    tooltip = tooltips.first
    trigger = find("[aria-describedby='#{tooltip[:id]}']")
    expect(trigger[:tabindex]).to eq "0"
    expect(tooltip.text(:all)).to eq "5–9 mi"
    expect(tooltip).not_to be_visible

    body_tooltip = find(".tooltip-body-imperial", visible: :all).find(:xpath, "ancestor::*[@role='tooltip']", visible: :all)
    expect(body_tooltip).to have_css(".tooltip-body-imperial", text: "5 mi", visible: :all)

    # Hover shows, mouseleave hides
    trigger.hover
    expect(tooltip).to be_visible
    expect(tooltip_position(tooltip[:id])).to include("top" => be_present, "left" => be_present)
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

    # Hover-then-focus stays visible until BOTH clear
    trigger.hover
    page.execute_script("arguments[0].focus()", trigger)
    find("body").hover
    expect(tooltip).to be_visible
    page.execute_script("arguments[0].blur()", trigger)
    expect(tooltip).not_to be_visible

    # Focus-then-hover is symmetric: stays through mouseleave until blur
    page.execute_script("arguments[0].focus()", trigger)
    trigger.hover
    find("body").hover
    expect(tooltip).to be_visible
    page.execute_script("arguments[0].blur()", trigger)
    expect(tooltip).not_to be_visible

    # Focus moving to another trigger hides the first
    triggers = tooltips.map { |t| find("[aria-describedby='#{t[:id]}']") }
    page.execute_script("arguments[0].focus()", triggers.first)
    expect(tooltips.first).to be_visible
    page.execute_script("arguments[0].focus()", triggers.last)
    expect(tooltips.first).not_to be_visible
    page.execute_script("arguments[0].blur()", triggers.last)

    # Clicking the trigger persists the tooltip through mouseleave until a body click
    trigger.hover
    trigger.click
    find("body").hover
    expect(tooltip).to be_visible
    find("body").click
    expect(tooltip).not_to be_visible

    # Click layering pushes each clicked tooltip's z-index higher
    tooltips.each { |t| find("[aria-describedby='#{t[:id]}']").click }
    z_indexes = tooltips.map { |t| tooltip_z_index(t[:id]).to_i }
    expect(z_indexes).to eq z_indexes.sort
    expect(z_indexes.last).to be > z_indexes.first
  end

  it "is accessible in dark mode" do
    visit "#{preview_url}?lookbook[display][theme]=dark"

    expect(page).to have_css("[role='tooltip']", visible: :all)
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)
  end
end
