# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Badge::Component, :js, type: :system do
  it "wraps the badge in a UI::Tooltip when title differs from text" do
    visit "/rails/view_components/ui/badge/component/notice_sm_with_title"

    tooltip = find("[role='tooltip']", visible: :all)
    expect(tooltip.text(:all)).to eq "Notice"
    expect(tooltip).not_to be_visible
    expect(page).to be_axe_clean.skipping(*SKIPPABLE_AXE_RULES)

    trigger = find("[aria-describedby='#{tooltip[:id]}']")
    expect(trigger).to have_text "N"
    expect(trigger.find("span.tw\\:cursor-help")).to be_present

    trigger.hover

    expect(tooltip).to be_visible
  end

  it "renders badges without a tooltip when no custom title is provided" do
    visit "/rails/view_components/ui/badge/component/success"

    expect(page).to have_css("span.tw\\:cursor-default")
    expect(page).to have_text "Donor"
    expect(page).not_to have_css("[role='tooltip']")
  end
end
