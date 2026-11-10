# frozen_string_literal: true

require "rails_helper"

RSpec.describe "color scheme switcher", :js, type: :system do
  let(:user) { FactoryBot.create(:user_confirmed) }

  def emulate_os(color_scheme)
    page.driver.with_playwright_page { it.emulate_media(colorScheme: color_scheme) }
  end

  it "applies and saves each option as it's picked, and follows the OS on system" do
    sign_in(user)
    visit "/my_account/edit"
    expect(page).to have_checked_field("System", visible: :all)
    expect(page).to have_no_css("body.dark")

    choose("Dark", allow_label_click: true)
    expect(page).to have_css("body.dark")
    wait_for { user.reload.color_scheme_dark? }
    # It's already saved, so leaving the page mustn't warn about unsaved changes
    expect(page.evaluate_script("jQuery('.primary-edit-user-form').dirtyForms('isDirty')")).to eq false

    # Dark isn't following the OS, so a change there can't undo it
    emulate_os("light")
    expect(page).to have_css("body.dark")

    choose("Light", allow_label_click: true)
    expect(page).to have_no_css("body.dark")
    wait_for { user.reload.color_scheme_light? }

    choose("System", allow_label_click: true)
    wait_for { user.reload.color_scheme_system? }
    emulate_os("dark")
    expect(page).to have_css("body.dark")
    emulate_os("light")
    expect(page).to have_no_css("body.dark")

    choose("Dark", allow_label_click: true)
    wait_for { user.reload.color_scheme_dark? }
    # A reload, to check the server renders what was saved
    visit page.current_url
    expect(page).to have_checked_field("Dark", visible: :all)
    expect(page).to have_css("body.dark")
  end
end
