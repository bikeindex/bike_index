# frozen_string_literal: true

require "rails_helper"

RSpec.describe PeriodSelect::Component, :js, type: :system do
  it "default preview hides custom form and toggles via collapse controller" do
    visit "/rails/view_components/period_select/component/default"

    expect(page).to have_css("#timeSelectionBtnGroup")
    expect(page).to have_css("a.period-select-standard.active[data-period='all']")
    expect(page).to have_css("form#timeSelectionCustom.tw\\:hidden", visible: :all)
    expect(page).to have_no_css("form#timeSelectionCustom", visible: true)

    click_button "custom"

    expect(page).to have_css("form#timeSelectionCustom", visible: true)

    click_button "custom"

    expect(page).to have_no_css("form#timeSelectionCustom", visible: true)
  end

  it "custom_selected preview shows the form initially" do
    visit "/rails/view_components/period_select/component/custom_selected"

    expect(page).to have_css("#timeSelectionBtnGroup.custom-period-selected")
    expect(page).to have_css("button#periodSelectCustom.active")
    expect(page).to have_css("form#timeSelectionCustom", visible: true)

    click_button "custom"

    expect(page).to have_no_css("form#timeSelectionCustom", visible: true)
  end

  it "with_include_future preview renders future buttons" do
    visit "/rails/view_components/period_select/component/with_include_future"

    expect(page).to have_css("a.period-select-standard.active[data-period='next_week']")
    expect(page).to have_css("a.period-select-standard[data-period='next_month']")
  end
end
