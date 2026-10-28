# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin recoveries", :js, type: :system do
  let(:user) { FactoryBot.create(:superuser) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
  let!(:stolen_record) do
    FactoryBot.create(:stolen_record_recovered, bike:, can_share_recovery: true, city: "Chicago",
      recovered_description: "Got it back, call me at 555-123-4567")
  end

  before do
    bike.owner.update(name: "Dr. Alex Chen")
    stolen_record.update_column(:recovery_display_status, "waiting_on_decision")
    Organization.example # Logging in lands on the admin dashboard, which reads it from the replica
    sign_in(user)
  end

  it "flags a story with personal info, and confirms before displaying it" do
    visit admin_recoveries_path

    story = find_field("display[#{stolen_record.id}][quote]")
    expect(page).to have_content("Contains phone number")
    expect(find_field("display[#{stolen_record.id}][quote_by]").value).to eq "Alex"

    story.fill_in with: "Got it back."
    expect(page).to have_no_content("Contains phone number")

    story.fill_in with: "Got it back, email me@example.com"
    expect(page).to have_content("Contains email address")

    dismiss_confirm { click_button "Display selected", match: :first }
    expect(RecoveryDisplay.count).to eq 0

    story.fill_in with: "Got it back, thanks to Bike Index!"
    click_button "Display selected", match: :first
    expect(page).to have_content("1 recovery displayed")
    expect(stolen_record.reload.recovery_display).to have_attributes(quote: "Got it back, thanks to Bike Index!", quote_by: "Alex")
  end
end
