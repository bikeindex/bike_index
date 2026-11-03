# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::Page::Component, :js, type: :system do
  before do
    FactoryBot.create(:stripe_price_basic)
    FactoryBot.create(:stripe_price_plus)
    FactoryBot.create(:stripe_price_patron)
  end

  it "keeps the submit labels on the selected amount" do
    visit "/rails/view_components/pages/donate/page/component/default"

    expect(page).to have_button("Become a member — $9.99/month", count: 2, wait: 10)
    expect_axe_clean

    choose "Patron membership", allow_label_click: true
    expect(page).to have_button("Become a member — $49.99/month", count: 2)

    choose "One-time", allow_label_click: true
    expect(page).to have_button("Donate $50", count: 2)
    expect(page).to have_no_button("Become a member — $49.99/month")

    fill_in "Other amount", with: "37.5"
    expect(page).to have_button("Donate $37.50", count: 2)
    expect(page).to have_no_checked_field("payment[amount_cents]", visible: :all)

    # Clearing it puts the preset back, so there's always an amount to donate
    fill_in "Other amount", with: ""
    expect(page).to have_button("Donate $50", count: 2)
    expect(page).to have_checked_field("payment[amount_cents]", with: "5000", visible: :all)

    choose "$100", allow_label_click: true
    expect(page).to have_button("Donate $100", count: 2)
    expect(page).to have_field("Other amount", with: "")

    choose "Monthly", allow_label_click: true
    find("a[data-amount='1000']").click
    expect(page).to have_button("Donate $1,000", count: 2)
    expect(page).to have_field("Other amount", with: "1000")
    expect(page).to have_css("a[data-amount='1000'][data-active='true']")
    expect(page).to have_current_path("/rails/view_components/pages/donate/page/component/default")
  end

  context "before donate--form's module has loaded" do
    def wait_for_donate_page_controller
      wait_for do
        page.evaluate_script(<<~JS)
          (() => {
            const element = document.querySelector('[data-controller~="donate--page"]')
            return !!(element && window.Stimulus?.getControllerForElementAndIdentifier(element, "donate--page"))
          })()
        JS
      end
    end

    it "lets a major gift card follow its link, and the closing CTA go to the form" do
      hold = hold_requests("**/controllers/donate/form_controller*")
      visit "/rails/view_components/pages/donate/page/component/default"
      wait_for_donate_page_controller

      find("a[data-amount='1000']").click
      expect(page).to have_current_path("/donate?initial_amount=1000")
      expect(page).to have_css("a[data-amount='1000'][data-active='true']")
      wait_for_donate_page_controller

      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
      page.all(:button, "Donate $1,000").last.click
      wait_for { page.evaluate_script("Math.abs(document.getElementById('donate-form').getBoundingClientRect().top) < 100") }
      expect(page).to have_current_path("/donate?initial_amount=1000")

      hold.release
    end
  end
end
