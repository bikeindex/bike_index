# frozen_string_literal: true

require "rails_helper"

RSpec.describe "My account", :js, type: :system do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let!(:secondary_email) { FactoryBot.create(:user_email, user:, email: "spare@example.com") }

  before { sign_in(user) }

  # The remove link sits inside the account form, so its DELETE can't come from a button_to
  # (the parser would drop the nested form) — it's Turbo's, guarded by an onclick
  it "asks before removing an email, and removes it only once confirmed" do
    visit "/my_account/edit"

    expect(page).to have_content("spare@example.com")

    expect(dismiss_confirm { click_link "Remove email" }).to match(/remove spare@example\.com/)
    expect(user.user_emails.pluck(:email)).to include("spare@example.com")

    accept_confirm { click_link "Remove email" }

    # Turbo issued the DELETE and followed the redirect back here
    expect(page).to have_content("spare@example.com removed")
    expect(user.user_emails.pluck(:email)).to_not include("spare@example.com")
  end
end
